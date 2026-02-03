# frozen_string_literal: true

require 'rails_helper'

shared_examples 'travel claim status check worker #perform' do |facility_type|
  before do
    if 'oracle_health'.casecmp?(facility_type)
      @sms_sender_id = Settings.vanotify.services.oracle_health.sms_sender_id
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
      @statsd_silent_failure_tag = CheckIn::Constants::STATSD_OH_SILENT_FAILURE_TAGS

      allow(redis_client).to receive(:facility_type).and_return('oh')
    else
      @sms_sender_id = Settings.vanotify.services.check_in.sms_sender_id
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
      @statsd_silent_failure_tag = CheckIn::Constants::STATSD_CIE_SILENT_FAILURE_TAGS

      allow(redis_client).to receive(:facility_type).and_return(nil)
    end
  end

  context "when #{facility_type} facility and travel claim returns success" do
    it 'sends notification with claim number' do
      worker = described_class.new

      allow(worker).to receive(:claim_status).and_return([claim_last4, @success_template_id])

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @success_template_id,
        claim_last4
      )

      worker.perform(uuid, appt_date)
    end
  end

  context "when #{facility_type} facility and travel claim returns success with more than one claim status" do
    it 'logs an info message and sends notification with success template' do
      worker = described_class.new

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @success_template_id,
        claim_last4
      )

      VCR.use_cassette('check_in/btsss/claim_status/multiple_claim_status_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_success).exactly(1).time
      expect(Rails.logger).to have_received(:info).with(
        'CheckIn::TravelClaimStatusCheckJob',
        {
          message: 'CheckIn::TravelClaimStatusCheckJob: Received multiple claim status response',
          status: 'multiple_response'
        }
      )
    end
  end

  context "when #{facility_type} facility and travel claim returns success with empty response" do
    it 'logs and sends notification with error message' do
      worker = described_class.new

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @error_template_id,
        ''
      )

      VCR.use_cassette('check_in/btsss/claim_status/claim_status_empty_response_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(Rails.logger).to have_received(:info).with(
        'CheckIn::TravelClaimStatusCheckJob',
        {
          message: 'CheckIn::TravelClaimStatusCheckJob: Received empty claim status response',
          status: 'empty_response'
        }
      )
    end
  end

  context "when #{facility_type} facility and claim status api returns failed status" do
    it 'sends notification with claim number and error template' do
      worker = described_class.new

      # Mock the claim_status method to return failed response with correct template ID
      allow(worker).to receive(:claim_status).and_return([claim_last4, @failed_template_id])

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @failed_template_id,
        claim_last4
      )

      worker.perform(uuid, appt_date)
    end
  end

  context "when #{facility_type} facility and claim status api returns invalid status" do
    it 'logs and sends notification with claim number and error template' do
      worker = described_class.new

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @error_template_id,
        claim_last4
      )

      VCR.use_cassette('check_in/btsss/claim_status/non_matching_claim_status_200', match_requests_on: [:host]) do
        worker.perform(uuid, appt_date)
      end

      expect(StatsD).to have_received(:increment).with(@statsd_error).exactly(1).time
      expect(Rails.logger).to have_received(:error).with(
        'CheckIn::TravelClaimStatusCheckJob',
        {
          message: 'CheckIn::TravelClaimStatusCheckJob: Received non-matching claim status',
          claim_status: 'Invalid',
          status: 'non_matching',
          uuid:
        }
      )
    end
  end

  context "when #{facility_type} facility and travel claim returns general error" do
    it 'sends notification with error message' do
      worker = described_class.new

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @error_template_id,
        ''
      )

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

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @error_template_id,
        ''
      )

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

      expect(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).with(
        uuid,
        appt_date,
        @timeout_template_id,
        ''
      )

      worker.perform(uuid, appt_date)

      expect(StatsD).to have_received(:increment).with(@statsd_timeout)
                                                 .exactly(1).time
    end
  end

  context "when #{facility_type} and both travel claim status & notification fails" do
    let(:travel_claim_status_resp) do
      Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408)
    end
    let(:forbidden_exception) { VANotify::Forbidden.new(403, 'test error message') }

    before do
      allow_any_instance_of(TravelClaim::Client).to receive(:claim_status).and_return(travel_claim_status_resp)
      allow(CheckIn::TravelClaimNotificationJob).to receive(:perform_async).and_raise(forbidden_exception)
    end

    it 'raises the error' do
      worker = described_class.new

      VCR.use_cassette('check_in/vanotify/send_sms_403_forbidden', match_requests_on: [:host],
                                                                   allow_playback_repeats: true) do
        expect { worker.perform(uuid, appt_date) }.to raise_error(VANotify::Forbidden)
      end

      expect(CheckIn::TravelClaimNotificationJob).to have_received(:perform_async).once
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
  let(:appointment_identifiers) do
    {
      data: {
        id: uuid,
        type: :appointment_identifier,
        attributes: {
          patientDFN: '123',
          stationNo: station_number,
          icn:,
          mobilePhone: patient_cell_phone,
          patientCellPhone: patient_cell_phone,
          facilityType: facility_type
        }
      }
    }
  end

  before do
    allow(TravelClaim::RedisClient).to receive(:build).and_return(redis_client)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)

    allow(redis_client).to receive_messages(patient_cell_phone:, token: redis_token, icn:,
                                            station_number:, facility_type: nil, save_token: nil)

    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(SemanticLogger::Logger).to receive(:new).and_return(Rails.logger)
  end

  describe '#perform for vista sites' do
    include_examples 'travel claim status check worker #perform', ''
  end

  describe '#perform for oracle health sites' do
    include_examples 'travel claim status check worker #perform', 'oracle_health'
  end
end
