# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::SubmissionJob do
  let(:claim) do
    require 'saved_claim/caregivers_assistance_claim'

    create(:caregivers_assistance_claim)
  end

  it 'defines #notify' do
    expect(described_class.new.respond_to?(:notify)).to eq(true)
  end

  it 'requires a parameter for notify' do
    expect { described_class.new.notify }
      .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
  end

  it 'defines retry_limits_for_notification' do
    expect(described_class.new.respond_to?(:retry_limits_for_notification)).to eq(true)
  end

  context 'retry_limits_for_notification' do
    it 'returns 0 and 10 when caregiver1010 is enabled' do
      allow(Flipper).to receive(:enabled?).with(:caregiver1010).and_return(true)
      expect(described_class.new.retry_limits_for_notification).to eq([1, 10])
    end

    it 'returns 10 when caregiver1010 is disabled' do
      allow(Flipper).to receive(:enabled?).with(:caregiver1010).and_return(false)
      expect(described_class.new.retry_limits_for_notification).to eq([10])
    end
  end

  it 'returns an array of integers from retry_limits_for_notification' do
    expect(described_class.new.retry_limits_for_notification).to eq([1, 10])
  end

  describe '#notify' do
    subject(:notify) { described_class.new.notify(params) }

    context 'caregiver1010 feature toggle on' do
      before do
        allow(Flipper).to receive(:enabled?).with(:caregiver1010).and_return(true)
      end

      context 'retry_count is 0' do
        let(:params) { { 'retry_count' => 0 } }

        it 'increments applications_retried statsd' do
          expect { notify }.to trigger_statsd_increment('api.form1010cg.async.applications_retried')
        end
      end

      context 'retry_count is not 0 or 10' do
        let(:params) { { 'retry_count' => 5 } }

        it 'does not increment applications_retried statsd' do
          expect { notify }.not_to trigger_statsd_increment('api.form1010cg.async.applications_retried')
        end

        it 'does not increment failed_ten_retries statsd' do
          expect do
            notify
          end.not_to trigger_statsd_increment('api.form1010cg.async.failed_ten_retries', tags: ["params:#{params}"])
        end
      end

      context 'retry_count is 10' do
        let(:params) { { 'retry_count' => 10 } }

        it 'increments failed_ten_retries statsd' do
          expect do
            notify
          end.to trigger_statsd_increment('api.form1010cg.async.failed_ten_retries', tags: ["params:#{params}"])
        end
      end
    end

    context 'caregiver1010 feature toggle off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:caregiver1010).and_return(false)
      end

      context 'no params' do
        let(:params) { {} }

        it 'increments failed_ten_retries statsd' do
          expect do
            notify
          end.to trigger_statsd_increment('api.form1010cg.async.failed_ten_retries', tags: ["params:#{params}"])
        end
      end
    end
  end

  describe 'when job has failed' do
    let(:msg) do
      {
        'args' => [claim.id]
      }
    end

    it 'increments statsd' do
      expect do
        described_class.new.sidekiq_retries_exhausted_block.call(msg)
      end.to trigger_statsd_increment('api.form1010cg.async.failed_no_retries_left', tags: ["claim_id:#{claim.id}"])
    end
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when there is a standarderror' do
      context 'caregiver1010 flipper enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver1010).and_return(true)
        end

        it 'increments statsd except applications_retried' do
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

      context 'caregiver1010 flipper not enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver1010).and_return(false)
        end

        it 'increments statsd' do
          allow_any_instance_of(Form1010cg::Service).to receive(
            :process_claim_v2!
          ).and_raise(StandardError)

          expect(StatsD).to receive(:increment).twice.with('api.form1010cg.async.retries')
          expect(StatsD).to receive(:increment).with('api.form1010cg.async.applications_retried')
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
    end

    context 'when the service throws a record parse error' do
      it 'rescues the error and increments statsd' do
        expect_any_instance_of(Form1010cg::Service).to receive(
          :process_claim_v2!
        ).and_raise(CARMA::Client::MuleSoftClient::RecordParseError.new)

        expect do
          job.perform(claim.id)
        end.to trigger_statsd_increment('api.form1010cg.async.record_parse_error', tags: ["claim_id:#{claim.id}"])

        expect(SavedClaim.exists?(id: claim.id)).to eq(true)
      end
    end

    context 'when claim cant be destroyed' do
      it 'logs the exception to sentry' do
        expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)
        error = StandardError.new
        expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(:destroy!).and_raise(error)

        expect(job).to receive(:log_exception_to_sentry).with(error)
        job.perform(claim.id)
      end
    end

    it 'calls process_claim_v2!' do
      expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)

      job.perform(claim.id)

      expect(SavedClaim::CaregiversAssistanceClaim.exists?(id: claim.id)).to eq(false)
    end
  end
end
