# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::SubmissionJob do
  let(:form) { VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json }
  let(:claim) { create(:caregivers_assistance_claim, form:) }
  let(:statsd_key_prefix) { described_class::STATSD_KEY_PREFIX }
  let(:zsf_tags) { described_class::DD_ZSF_TAGS }
  let(:email_address) { 'jane.doe@example.com' }
  let(:form_with_email) do
    data = JSON.parse(VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json)
    data['veteran']['email'] = email_address
    data.to_json
  end

  before do
    allow(VANotify::EmailJob).to receive(:perform_async)
  end

  it 'has a retry count of 16' do
    expect(described_class.get_sidekiq_options['retry']).to eq(16)
  end

  it 'defines #notify' do
    expect(described_class.new.respond_to?(:notify)).to be(true)
  end

  it 'requires a parameter for notify' do
    expect { described_class.new.notify }
      .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
  end

  it 'defines retry_limits_for_notification' do
    expect(described_class.new.respond_to?(:retry_limits_for_notification)).to be(true)
  end

  it 'returns an array of integers from retry_limits_for_notification' do
    expect(described_class.new.retry_limits_for_notification).to eq([1, 10])
  end

  describe '#notify' do
    subject(:notify) { described_class.new.notify(params) }

    let(:tags) { ["params:#{params}", "claim_id:#{claim.id}"] }

    before { allow(StatsD).to receive(:increment) }

    context 'retry_count is 0' do
      let(:params) { { 'retry_count' => 0, 'args' => [claim.id] } }

      it 'increments applications_retried statsd' do
        expect(StatsD).to receive(:increment).with('api.form1010cg.async.applications_retried')
        notify
      end
    end

    context 'retry_count is not 0 or 9' do
      let(:params) { { 'retry_count' => 5, 'args' => [claim.id] } }

      it 'does not increment applications_retried statsd' do
        expect(StatsD).not_to receive(:increment).with('api.form1010cg.async.applications_retried')
        notify
      end

      it 'does not increment failed_ten_retries statsd' do
        expect(StatsD).not_to receive(:increment).with('api.form1010cg.async.failed_ten_retries', tags:)
        notify
      end
    end

    context 'retry_count is 9' do
      let(:params) { { 'retry_count' => 9, 'args' => [claim.id] } }

      it 'increments failed_ten_retries statsd' do
        expect(StatsD).to receive(:increment).with('api.form1010cg.async.failed_ten_retries', tags:)
        notify
      end
    end
  end

  describe 'when retries are exhausted' do
    let(:msg) do
      {
        'args' => [claim.id]
      }
    end

    context 'when the parsed form does not have an email' do
      it 'only increments StatsD' do
        described_class.within_sidekiq_retries_exhausted_block(msg) do
          allow(StatsD).to receive(:increment)
          expect(StatsD).to receive(:increment).with(
            "#{statsd_key_prefix}failed_no_retries_left",
            tags: ["claim_id:#{claim.id}"]
          )
          expect(StatsD).to receive(:increment).with('silent_failure', tags: zsf_tags)
          expect(VANotify::EmailJob).not_to receive(:perform_async)
        end
      end
    end

    context 'when the parsed form has an email' do
      let(:form) { form_with_email }

      let(:api_key) { Settings.vanotify.services.health_apps_1010.api_key }
      let(:template_id) { Settings.vanotify.services.health_apps_1010.template_id.form1010_cg_failure_email }
      let(:template_params) do
        [
          email_address,
          template_id,
          {
            'salutation' => "Dear #{claim.parsed_form.dig('veteran', 'fullName', 'first')},"
          },
          api_key,
          {
            callback_metadata: {
              notification_type: 'error',
              form_number: claim.form_id,
              statsd_tags: zsf_tags
            }
          }
        ]
      end

      it 'increments StatsD and sends the failure email' do
        described_class.within_sidekiq_retries_exhausted_block(msg) do
          allow(StatsD).to receive(:increment)
          expect(StatsD).to receive(:increment).with(
            "#{statsd_key_prefix}failed_no_retries_left",
            tags: ["claim_id:#{claim.id}"]
          )

          expect(VANotify::EmailJob).to receive(:perform_async).with(*template_params)
          expect(StatsD).to receive(:increment).with(
            "#{statsd_key_prefix}submission_failure_email_sent", tags: ["claim_id:#{claim.id}"]
          )
        end
      end
    end
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when there is a standarderror' do
      it 'increments statsd except applications_retried' do
        start_time = Time.current
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { start_time }
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC, :float_millisecond)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_THREAD_CPUTIME_ID, :float_millisecond)
        expected_arguments = { context: :process_async, event: :failure, start_time: }
        auditor_double = instance_double(Form1010cg::Auditor)
        allow(Form1010cg::Auditor).to receive(:new) { auditor_double }
        expect(auditor_double).to receive(:log_caregiver_request_duration).with(**expected_arguments).twice

        allow_any_instance_of(Form1010cg::Service).to receive(
          :process_claim_v2!
        ).and_raise(StandardError)

        expect(StatsD).to receive(:increment).twice.with('api.form1010cg.async.retries')
        expect(StatsD).not_to receive(:increment).with('api.form1010cg.async.applications_retried')
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).twice

        # If we're stubbing StatsD, we also have to expect this because of SavedClaim's after_create metrics logging
        expect(StatsD).to receive(:increment).with('saved_claim.create', { tags: ['form_id:10-10CG'] })

        2.times do
          expect do
            job.perform(claim.id)
          end.to raise_error(StandardError)
        end
      end
    end

    context 'when the service throws a record parse error' do
      before do
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC, :float_millisecond)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_THREAD_CPUTIME_ID, :float_millisecond)
      end

      context 'form has email' do
        let(:form) { form_with_email }

        it 'rescues the error, increments statsd, and attempts to send failure email' do
          start_time = Time.current
          expected_arguments = { context: :process_async, event: :failure, start_time: }
          expect_any_instance_of(Form1010cg::Auditor).to receive(:log_caregiver_request_duration)
            .with(**expected_arguments)
          allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { start_time }

          expect_any_instance_of(Form1010cg::Service).to receive(
            :process_claim_v2!
          ).and_raise(CARMA::Client::MuleSoftClient::RecordParseError.new)

          expect(SavedClaim.exists?(id: claim.id)).to be(true)

          expect(VANotify::EmailJob).to receive(:perform_async)
          expect(StatsD).to receive(:increment).with(
            "#{statsd_key_prefix}submission_failure_email_sent", tags: ["claim_id:#{claim.id}"]
          )
          expect(StatsD).to receive(:increment).with(
            "#{statsd_key_prefix}record_parse_error",
            tags: ["claim_id:#{claim.id}"]
          )

          job.perform(claim.id)
        end
      end

      context 'form does not have email' do
        it 'rescues the error, increments statsd, and attempts to send failure email' do
          start_time = Time.current
          expected_arguments = { context: :process_async, event: :failure, start_time: }
          expect_any_instance_of(Form1010cg::Auditor).to receive(:log_caregiver_request_duration)
            .with(**expected_arguments)
          allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { start_time }

          expect_any_instance_of(Form1010cg::Service).to receive(
            :process_claim_v2!
          ).and_raise(CARMA::Client::MuleSoftClient::RecordParseError.new)

          expect do
            job.perform(claim.id)
          end.to trigger_statsd_increment('api.form1010cg.async.record_parse_error', tags: ["claim_id:#{claim.id}"])
            .and trigger_statsd_increment('silent_failure', tags: zsf_tags)

          expect(SavedClaim.exists?(id: claim.id)).to be(true)
          expect(VANotify::EmailJob).not_to receive(:perform_async)
        end
      end
    end

    context 'when claim cant be destroyed' do
      it 'logs the exception to sentry' do
        expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)
        error = StandardError.new
        expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(:destroy!).and_raise(error)

        expect(job).to receive(:log_exception_to_sentry).with(error, { claim_id: claim.id })
        job.perform(claim.id)
      end
    end

    it 'calls process_claim_v2!' do
      start_time = Time.current
      expected_arguments = { context: :process_async, event: :success, start_time: }
      expect_any_instance_of(Form1010cg::Auditor).to receive(:log_caregiver_request_duration).with(**expected_arguments)

      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { start_time }
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC, :float_millisecond)
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_THREAD_CPUTIME_ID, :float_millisecond)

      expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)

      job.perform(claim.id)

      expect(SavedClaim::CaregiversAssistanceClaim.exists?(id: claim.id)).to be(false)
    end
  end
end
