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

      @statsd_success = CheckIn::TravelClaimSubmissionWorker::OH_STATSD_BTSSS_SUCCESS
      @statsd_duplicate = CheckIn::TravelClaimSubmissionWorker::OH_STATSD_BTSSS_DUPLICATE
      @statsd_timeout = CheckIn::TravelClaimSubmissionWorker::OH_STATSD_BTSSS_TIMEOUT
      @statsd_error = CheckIn::TravelClaimSubmissionWorker::OH_STATSD_BTSSS_ERROR

      allow(redis_client).to receive(:facility_type).and_return('oh')
    else
      @sms_sender_id = Settings.vanotify.services.check_in.sms_sender_id
      @success_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_success_text
      @duplicate_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_duplicate_text
      @timeout_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_timeout_text
      @error_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_error_text

      @statsd_success = CheckIn::TravelClaimSubmissionWorker::CIE_STATSD_BTSSS_SUCCESS
      @statsd_duplicate = CheckIn::TravelClaimSubmissionWorker::CIE_STATSD_BTSSS_DUPLICATE
      @statsd_timeout = CheckIn::TravelClaimSubmissionWorker::CIE_STATSD_BTSSS_TIMEOUT
      @statsd_error = CheckIn::TravelClaimSubmissionWorker::CIE_STATSD_BTSSS_ERROR

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

      Sidekiq::Testing.inline! do
        VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_200', match_requests_on: [:host]) do
          worker.perform(uuid, appt_date)
        end
      end

      expect(StatsD).to have_received(:increment).with(@statsd_success).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_SUCCESS).exactly(1).time
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

      Sidekiq::Testing.inline! do
        VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_400_exists', match_requests_on: [:host]) do
          worker.perform(uuid, appt_date)
        end
      end

      expect(StatsD).to have_received(:increment).with(@statsd_duplicate).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_SUCCESS).exactly(1).time
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

      Sidekiq::Testing.inline! do
        VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_500', match_requests_on: [:host]) do
          worker.perform(uuid, appt_date)
        end
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_SUCCESS).exactly(1).time
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

      Sidekiq::Testing.inline! do
        VCR.use_cassette('check_in/btsss/token/token_500', match_requests_on: [:host]) do
          worker.perform(uuid, appt_date)
        end
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(StatsD).to have_received(:increment)
        .with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_SUCCESS).exactly(1).time
    end
  end

  context "when #{facility_type} facility and send_sms returns an error" do
    it 'handles the error' do
      worker = described_class.new
      expect(worker).to receive(:log_exception_to_sentry).with(
        instance_of(Common::Exceptions::BackendServiceException),
        { phone_number: patient_cell_phone_last_four, template_id: @success_template_id, claim_number: claim_last4 },
        { error: :check_in_va_notify_job, team: 'check-in' }
      )

      expect(StatsD).not_to receive(:increment)
        .with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_SUCCESS)
      expect(StatsD).to receive(:increment)
        .with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_ERROR).exactly(1).time

      Sidekiq::Testing.inline! do
        VCR.use_cassette('check_in/vanotify/send_sms_403_forbidden', match_requests_on: [:host]) do
          VCR.use_cassette('check_in/btsss/submit_claim/submit_claim_200', match_requests_on: [:host]) do
            expect { worker.perform(uuid, appt_date) }.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end
end

describe CheckIn::TravelClaimSubmissionWorker, type: :worker do
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
    allow(Flipper).to receive(:enabled?).with('check_in_experience_travel_btsss_ssm_urls_enabled').and_return(false)

    allow(redis_client).to receive(:patient_cell_phone).and_return(patient_cell_phone)
    allow(redis_client).to receive(:token).and_return(redis_token)
    allow(redis_client).to receive(:icn).and_return(icn)
    allow(redis_client).to receive(:station_number).and_return(station_number)
    allow(redis_client).to receive(:facility_type).and_return(nil)

    allow(StatsD).to receive(:increment)
  end

  describe '#perform for vista sites' do
    include_examples 'travel claims worker #perform', ''
  end

  describe '#perform for oracle health sites' do
    include_examples 'travel claims worker #perform', 'oracle_health'
  end

  context 'travel claim throws timeout error' do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
    end

    it 'throws timeout exception and sends notification with cie error message' do
      worker = described_class.new
      notify_client = double

      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                                .and_return(notify_client)

      expect(notify_client).to receive(:send_sms).with(
        phone_number: patient_cell_phone,
        template_id: 'cie_fake_timeout_template_id',
        sms_sender_id: 'cie_fake_sms_sender_id',
        personalisation: { claim_number: nil, appt_date: notify_appt_date }
      )

      Sidekiq::Testing.inline! do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(CheckIn::TravelClaimSubmissionWorker::CIE_STATSD_BTSSS_TIMEOUT)
                                                 .exactly(1).time
      expect(StatsD).to have_received(:increment).with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_SUCCESS)
                                                 .exactly(1).time
    end

    it 'throws timeout exception and sends notification with oh error message' do
      allow(redis_client).to receive(:facility_type).and_return('oh')

      worker = described_class.new
      notify_client = double

      expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.check_in.api_key)
                                                .and_return(notify_client)

      expect(notify_client).to receive(:send_sms).with(
        phone_number: patient_cell_phone,
        template_id: 'oh_fake_timeout_template_id',
        sms_sender_id: 'oh_fake_sms_sender_id',
        personalisation: { claim_number: nil, appt_date: notify_appt_date }
      )

      Sidekiq::Testing.inline! do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(CheckIn::TravelClaimSubmissionWorker::OH_STATSD_BTSSS_TIMEOUT)
                                                 .exactly(1).time
      expect(StatsD).to have_received(:increment).with(CheckIn::TravelClaimSubmissionWorker::STATSD_NOTIFY_SUCCESS)
                                                 .exactly(1).time
    end
  end
end
