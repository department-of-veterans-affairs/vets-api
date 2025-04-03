# frozen_string_literal: true

require 'rails_helper'

shared_examples 'travel claim status check worker #perform' do |facility_type|
  before do
    if 'oracle_health'.casecmp?(facility_type)
      @success_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_success_text
      @duplicate_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_duplicate_text
      @timeout_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_timeout_text
      @failed_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_failure_text
      @error_template_id = Settings.vanotify.services.oracle_health.template_id.claim_submission_error_text

      @statsd_success = CheckIn::Constants::OH_STATSD_BTSSS_SUCCESS
      @statsd_duplicate = CheckIn::Constants::OH_STATSD_BTSSS_DUPLICATE
      @statsd_timeout = CheckIn::Constants::OH_STATSD_BTSSS_TIMEOUT
      @statsd_failed_claim = CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE
      @statsd_error = CheckIn::Constants::OH_STATSD_BTSSS_ERROR

      allow(redis_client).to receive(:facility_type).and_return('oh')
      @expected_facility_type = 'oh'
    else
      @success_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_success_text
      @duplicate_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_duplicate_text
      @timeout_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_timeout_text
      @failed_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_failure_text
      @error_template_id = Settings.vanotify.services.check_in.template_id.claim_submission_error_text

      @statsd_success = CheckIn::Constants::CIE_STATSD_BTSSS_SUCCESS
      @statsd_duplicate = CheckIn::Constants::CIE_STATSD_BTSSS_DUPLICATE
      @statsd_timeout = CheckIn::Constants::CIE_STATSD_BTSSS_TIMEOUT
      @statsd_failed_claim = CheckIn::Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE
      @statsd_error = CheckIn::Constants::CIE_STATSD_BTSSS_ERROR

      allow(redis_client).to receive(:facility_type).and_return(nil)
      @expected_facility_type = nil
    end
  end

  def expect_notification_job_enqueued(template_id, claim_number = nil)
    expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
      mobile_phone: patient_cell_phone,
      appointment_date: appt_date,
      template_id:,
      claim_number:,
      facility_type: @expected_facility_type
    )
  end

  context "when #{facility_type} facility and travel claim returns success" do
    it 'sends notification with success template' do
      worker = described_class.new

      expect_notification_job_enqueued(@success_template_id, claim_last4)

      VCR.use_cassette('check_in/btsss/claim_status/claim_status_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_success).exactly(1).time
    end
  end

  context "when #{facility_type} facility and travel claim returns success with more than one claim status" do
    it 'logs an info message and sends notification with success template' do
      worker = described_class.new

      expect_notification_job_enqueued(@success_template_id, claim_last4)

      VCR.use_cassette('check_in/btsss/claim_status/multiple_claim_status_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_success).exactly(1).time
      expect(Sidekiq.logger).to have_received(:info).with({
                                                            message: 'Received multiple claim status response',
                                                            uuid:
                                                          })
    end
  end

  context "when #{facility_type} facility and travel claim returns success with empty response" do
    it 'logs and sends notification with error message' do
      worker = described_class.new

      expect_notification_job_enqueued(@error_template_id, nil)

      VCR.use_cassette('check_in/btsss/claim_status/claim_status_empty_response_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(Sidekiq.logger).to have_received(:info).with({
                                                            message: 'Received empty claim status response',
                                                            uuid:
                                                          })
    end
  end

  context "when #{facility_type} facility and claim status api returns failed status" do
    it 'logs and sends notification with error message' do
      worker = described_class.new

      expect_notification_job_enqueued(@failed_template_id, claim_last4)

      VCR.use_cassette('check_in/btsss/claim_status/failed_claim_status_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_failed_claim).exactly(1).time
    end
  end

  context "when #{facility_type} facility and claim status api returns invalid status" do
    it 'logs and sends notification with error message' do
      worker = described_class.new

      expect_notification_job_enqueued(@error_template_id, claim_last4)

      VCR.use_cassette('check_in/btsss/claim_status/non_matching_claim_status_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(Sidekiq.logger).to have_received(:info).with({
                                                            message: 'Received non-matching claim status',
                                                            claim_status: 'Invalid',
                                                            uuid:
                                                          })
    end
  end

  context "when #{facility_type} facility and travel claim returns general error" do
    it 'sends notification with error message' do
      worker = described_class.new

      expect_notification_job_enqueued(@error_template_id, nil)

      VCR.use_cassette('check_in/btsss/claim_status/claim_status_500', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
    end
  end

  context "when #{facility_type} facility and travel claim token call returns error" do
    before do
      allow(redis_client).to receive(:token).and_return(nil)
    end

    it 'sends notification with error message' do
      worker = described_class.new

      expect_notification_job_enqueued(@error_template_id, nil)

      VCR.use_cassette('check_in/btsss/token/token_500', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
    end
  end

  context "when #{facility_type} and travel claim throws timeout error" do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
    end

    it 'sends notification with timeout error message' do
      worker = described_class.new

      expect_notification_job_enqueued(@timeout_template_id, nil)

      worker.perform(uuid, appt_date)

      expect(StatsD).to have_received(:increment).with(@statsd_timeout).exactly(1).time
    end
  end

  context "when #{facility_type} and travel claim status fails" do
    let(:travel_claim_status_resp) do
      Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408)
    end

    before do
      allow_any_instance_of(TravelClaim::Client).to receive(:claim_status).and_return(travel_claim_status_resp)
    end

    it 'sends notification with correct timeout template ID' do
      worker = described_class.new

      expect_notification_job_enqueued(@timeout_template_id, nil)

      worker.perform(uuid, appt_date)

      expect(StatsD).to have_received(:increment).with(@statsd_timeout).exactly(1).time
    end
  end
end

describe CheckIn::TravelClaimStatusCheckJob, type: :worker do
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
    allow(Flipper).to receive(:enabled?).with(:va_notify_notification_creation).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:va_notify_custom_errors).and_return(true)

    allow(redis_client).to receive_messages(patient_cell_phone:, token: redis_token, icn:,
                                            station_number:, facility_type: nil)

    allow(StatsD).to receive(:increment)
    allow(Sidekiq.logger).to receive(:info)
    allow(SemanticLogger::Logger).to receive(:new).and_return(Sidekiq.logger)
    allow(CheckIn::TravelClaimNotificationJob).to receive(:perform_async)
  end

  describe '#perform for vista sites' do
    include_examples 'travel claim status check worker #perform', 'vista'
  end

  describe '#perform for oracle health sites' do
    include_examples 'travel claim status check worker #perform', 'oracle_health'
  end
end
