# frozen_string_literal: true

require 'rails_helper'

shared_examples 'travel claims worker #perform' do |facility_type|
  before do
    if 'oracle_health'.casecmp?(facility_type)
      @sms_sender_id = Settings.vanotify.services.oracle_health.sms_sender_id
      @success_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_success_text
      @duplicate_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_duplicate_text
      @timeout_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_timeout_text
      @error_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_error_text

      @statsd_success = CheckIn::Constants::OH_STATSD_BTSSS_SUCCESS
      @statsd_duplicate = CheckIn::Constants::OH_STATSD_BTSSS_DUPLICATE
      @statsd_timeout = CheckIn::Constants::OH_STATSD_BTSSS_TIMEOUT
      @statsd_error = CheckIn::Constants::OH_STATSD_BTSSS_ERROR
      @statsd_notify_success = CheckIn::Constants::STATSD_NOTIFY_SUCCESS
      @statsd_silent_failure_tag = CheckIn::Constants::STATSD_OH_SILENT_FAILURE_TAGS

      allow(redis_client).to receive(:facility_type).and_return('oh')
    else
      @sms_sender_id = Settings.vanotify.services.check_in.sms_sender_id
      @success_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_success_text
      @duplicate_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_duplicate_text
      @timeout_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_timeout_text
      @error_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_error_text

      @statsd_success = CheckIn::Constants::CIE_STATSD_BTSSS_SUCCESS
      @statsd_duplicate = CheckIn::Constants::CIE_STATSD_BTSSS_DUPLICATE
      @statsd_timeout = CheckIn::Constants::CIE_STATSD_BTSSS_TIMEOUT
      @statsd_error = CheckIn::Constants::CIE_STATSD_BTSSS_ERROR
      @statsd_notify_success = CheckIn::Constants::STATSD_NOTIFY_SUCCESS
      @statsd_silent_failure_tag = CheckIn::Constants::STATSD_CIE_SILENT_FAILURE_TAGS

      allow(redis_client).to receive(:facility_type).and_return(nil)
    end
  end

  context "when #{facility_type} facility and travel claim returns success" do
    it 'sends notification with success template' do
      worker = described_class.new
      notify_client = double

      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                                .and_return(notify_client)
      expect(notify_client).to receive(:send_sms).with(
        phone_number: patient_cell_phone,
        template_id: @success_template_id,
        sms_sender_id: @sms_sender_id,
        personalisation: { claim_number: claim_last4, appt_date: notify_appt_date }
      )
      expect(worker).not_to receive(:log_exception_to_sentry)

      VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_success).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS).exactly(1).time
    end
  end

  context "when #{facility_type} facility and travel claim returns duplicate error" do
    it 'sends notification with duplicate message' do
      worker = described_class.new
      notify_client = double
      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                                .and_return(notify_client)
      expect(notify_client).to receive(:send_sms).with(
        phone_number: patient_cell_phone,
        template_id: @duplicate_template_id,
        sms_sender_id: @sms_sender_id,
        personalisation: { claim_number: nil, appt_date: notify_appt_date }
      )
      expect(worker).not_to receive(:log_exception_to_sentry)

      VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_400_exists', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_duplicate).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS).exactly(1).time
    end
  end

  context "when #{facility_type} facility and travel claim returns general error" do
    it 'sends notification with error message' do
      worker = described_class.new
      notify_client = double
      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                                .and_return(notify_client)
      expect(notify_client).to receive(:send_sms).with(
        phone_number: patient_cell_phone,
        template_id: @error_template_id,
        sms_sender_id: @sms_sender_id,
        personalisation: { claim_number: nil, appt_date: notify_appt_date }
      )
      expect(worker).not_to receive(:log_exception_to_sentry)

      VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_500', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS).exactly(1).time
    end
  end

  context "when #{facility_type} facility and travel claim token call returns error" do
    before do
      allow(redis_client).to receive(:token).and_return(nil)
    end

    it 'sends notification with error message' do
      worker = described_class.new
      notify_client = double
      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                                .and_return(notify_client)
      expect(notify_client).to receive(:send_sms).with(
        phone_number: patient_cell_phone,
        template_id: @error_template_id,
        sms_sender_id: @sms_sender_id,
        personalisation: { claim_number: nil, appt_date: notify_appt_date }
      )
      expect(worker).not_to receive(:log_exception_to_sentry)

      VCR.use_cassette('check_in/btsss/token/token_500', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS).exactly(1).time
    end
  end

  context "when #{facility_type} facility and send_sms returns an error after retrying" do
    let(:notify_client) { instance_double(VaNotify::Service) }
    let(:forbidden_exception) { VANotify::Forbidden.new(403, 'test error message') }

    before do
      allow(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                               .and_return(notify_client)
      allow(notify_client).to receive(:send_sms).with(any_args).and_raise(forbidden_exception)
    end

    it 'handles the error' do
      worker = described_class.new
      expect(worker).to receive(:log_exception_to_sentry).with(
        instance_of(VANotify::Forbidden),
        { phone_number: patient_cell_phone_last_four, template_id: @success_template_id, claim_number: claim_last4 },
        { error: :check_in_va_notify_job, team: 'check-in' }
      )

      expect(notify_client).to receive(:send_sms).with(any_args).exactly(4).times
      expect(StatsD).not_to receive(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)
      expect(StatsD).to receive(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_ERROR).exactly(1).time

      VCR.use_cassette('check_in/vanotify/send_sms_403_forbidden', match_requests_on: [:host],
                                                                   allow_playback_repeats: true) do
        VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_200', match_requests_on: [:host]) do
          expect { worker.perform(uuid, appt_date) }.to raise_error(VANotify::Forbidden)
        end
      end
    end
  end

  context "when #{facility_type} facility and both submit_claim & send_sms returns an error after retrying" do
    let(:notify_client) { instance_double(VaNotify::Service) }
    let(:forbidden_exception) { VANotify::Forbidden.new(403, 'test error message') }

    before do
      allow(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                               .and_return(notify_client)
      allow(notify_client).to receive(:send_sms).with(any_args).and_raise(forbidden_exception)
    end

    it 'logs the silent_failure error' do
      worker = described_class.new
      expect(worker).to receive(:log_exception_to_sentry).with(
        instance_of(VANotify::Forbidden),
        { phone_number: patient_cell_phone_last_four, template_id: @error_template_id, claim_number: nil },
        { error: :check_in_va_notify_job, team: 'check-in' }
      )

      expect(notify_client).to receive(:send_sms).with(any_args).exactly(4).times
      expect(StatsD).not_to receive(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_SUCCESS)
      expect(StatsD).to receive(:increment).with(CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
                                                 { tags: @statsd_silent_failure_tag })
                                           .exactly(1).time
      expect(StatsD).to receive(:increment)
        .with(CheckIn::Constants::STATSD_NOTIFY_ERROR).exactly(1).time

      VCR.use_cassette('check_in/vanotify/send_sms_403_forbidden', match_requests_on: [:host],
                                                                   allow_playback_repeats: true) do
        VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_400_multiple', match_requests_on: [:host]) do
          expect { worker.perform(uuid, appt_date) }.to raise_error(VANotify::Forbidden)
        end
      end
    end
  end

  context "when #{facility_type} facility and submit claim times out" do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
    end

    context 'when feature flag is on' do
      it 'enqueues claim status job' do
        worker = described_class.new

        expect do
          worker.perform(uuid, appt_date)
        end.to change(CheckIn::TravelClaimStatusCheckJob.jobs, :size).by(1)

        expect(StatsD).not_to have_received(:increment).with(@statsd_timeout)
        expect(StatsD).not_to have_received(:increment).with(@statsd_notify_success)
      end
    end

    context 'when feature flag is off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:check_in_experience_check_claim_status_on_timeout)
                                            .and_return(false)
      end

      it 'sends notification with error message' do
        worker = described_class.new
        notify_client = double

        expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                                  .and_return(notify_client)
        expect(notify_client).to receive(:send_sms).with(
          phone_number: patient_cell_phone,
          template_id: @timeout_template_id,
          sms_sender_id: @sms_sender_id,
          personalisation: { claim_number: nil, appt_date: notify_appt_date }
        )

        expect do
          worker.perform(uuid, appt_date)
        end.not_to change(CheckIn::TravelClaimStatusCheckJob.jobs, :size)

        expect(StatsD).to have_received(:increment).with(@statsd_timeout)
        expect(StatsD).to have_received(:increment).with(@statsd_notify_success)
      end
    end
  end
end

describe CheckIn::TravelClaimSubmissionJob, type: :worker do
  let(:uuid) { '3bcd636c-d4d3-4349-9058-03b2f6b38ced' }
  let(:appt_date) { '2022-09-01' }
  let(:patient_cell_phone) { '123-345-7777' }
  let(:patient_cell_phone_last_four) { '7777' }
  let(:station_number) { '500xyz' }
  let(:redis_token) { '123-456' }
  let(:icn) { '123456' }
  let(:notify_appt_date) { 'Sep 01' }
  let(:claim_last4) { '1666' }
  let(:facility_type) { 'oh' }
  let(:redis_client) { double }

  before do
    allow(TravelClaim::RedisClient).to receive(:build).and_return(redis_client)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
    allow(Flipper).to receive(:enabled?).with(:check_in_experience_check_claim_status_on_timeout)
                                        .and_return(true)
    allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:va_notify_custom_errors).and_return(true)

    allow(redis_client).to receive_messages(patient_cell_phone:, token: redis_token, icn:,
                                            station_number:, facility_type: nil)

    allow(StatsD).to receive(:increment)
  end

  describe '#perform for vista sites' do
    include_examples 'travel claims worker #perform', ''
  end

  describe '#perform for oracle health sites' do
    include_examples 'travel claims worker #perform', 'oracle_health'
  end
end
