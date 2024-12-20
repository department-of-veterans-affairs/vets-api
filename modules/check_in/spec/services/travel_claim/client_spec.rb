# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Client do
  subject { described_class.build(check_in:, client_number:) }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:client_number) { 'test-client-number' }

  before do
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
  end

  describe '.build' do
    it 'returns an instance of described_class' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe 'extends' do
    it 'extends forwardable' do
      expect(described_class.ancestors).to include(Forwardable)
    end
  end

  describe '#initialize' do
    it 'has settings attribute' do
      expect(subject.settings).to be_a(Config::Options)
    end

    it 'has a session' do
      expect(subject.check_in).to be_a(CheckIn::V2::Session)
    end

    it 'has the client_number it is initialized with' do
      expect(subject.client_number).to eq(client_number)
    end

    it 'has default client_number if not initialized with it' do
      cls = described_class.build(check_in:)
      expect(cls.client_number).to eq(Settings.check_in.travel_reimbursement_api_v2.client_number)
    end
  end

  describe '#token' do
    context 'when veis auth service returns a success response' do
      let(:token_response) do
        {
          token_type: 'Bearer',
          expires_in: 3599,
          ext_expires_in: 3599,
          access_token: 'testtoken'
        }
      end
      let(:veis_token_response) { Faraday::Response.new(body: token_response, status: 200) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(veis_token_response)
      end

      it 'yields to block' do
        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_yield(Faraday::Request.new)

        subject.token
      end

      it 'returns token' do
        expect(subject.token).to eq(veis_token_response)
      end
    end

    context 'when veis auth service returns a 401 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'invalid_client' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and raises exception' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)
        expect { subject.token }.to raise_exception(exception)
      end
    end

    context 'when veis auth service returns a 500 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and raises exception' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)
        expect { subject.token }.to raise_exception(exception)
      end
    end
  end

  describe '#submit_claim' do
    let(:access_token) { 'test-token' }
    let(:icn) { 'test-patient-icn' }
    let(:appt_date) { '2022-09-01' }

    context 'when claims service returns success response' do
      let(:claim_response) do
        { value: {
            claimNumber: 'TC202207000011666'
          },
          statusCode: 200 }
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(claim_response)
      end

      it 'returns claims number' do
        expect(subject.submit_claim(token: access_token, patient_icn: icn,
                                    appointment_date: appt_date)).to eq(claim_response)
      end
    end

    context 'when claims service returns a 500 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and returns original error' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim(token: access_token, patient_icn: icn, appointment_date: appt_date)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when claims service returns a 400 error response' do
      let(:resp) do
        Faraday::Response.new(
          body: { error: { currentDate: '[07/29/2022 01:05:41 PM]',
                           message: '07/29/2022 : There were multiple appointments for that date' } }, status: 400
        )
      end
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and returns original error' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim(token: access_token, patient_icn: icn, appointment_date: appt_date)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when claims service returns a 401 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Unauthorized' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and returns original error' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim(token: access_token, patient_icn: icn, appointment_date: appt_date)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when claims service returns a 404 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Not Found' }, status: 404) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and raises exception' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim(token: access_token, patient_icn: icn, appointment_date: appt_date)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when call to claims service times out' do
      let(:resp) { Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408) }
      let(:err_msg) { { message: 'BTSSS Timeout Error', uuid: } }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(Faraday::TimeoutError)
      end

      it 'logs message and raises exception' do
        expect(Rails.logger).to receive(:error).with(err_msg)

        response = subject.submit_claim(token: access_token, patient_icn: icn, appointment_date: appt_date)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end
  end

  describe '#claim_status' do
    let(:token) { 'test-token' }
    let(:patient_icn) { 'test-patient-icn' }
    let(:start_range_date) { '2022-09-01' }
    let(:end_range_date) { '2022-09-01' }

    context 'when claims status returns a success response' do
      let(:status_response) do
        [
          {
            aptDateTime: '2022-09-01',
            aptId: '7d53abcf-a916-ef11-aa8a-001cc83064a6',
            aptSourceSystem: 'VISTA',
            aptSourceSystemId: 'A;3240606.093;4204',
            claimNum: 'TC2024061234567890',
            claimStatus: 'ClaimSubmitted',
            claimLastModDateTime: '2022-09-01',
            facilityStationNum: '679'
          }
        ]
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(status_response)
      end

      it 'returns status response' do
        expect(subject.claim_status(token:, patient_icn:, start_range_date:, end_range_date:)).to eq(status_response)
      end
    end

    context 'when claims status returns an error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and returns original error' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.claim_status(token:, patient_icn:, start_range_date:, end_range_date:)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when call to claims status times out' do
      let(:resp) { Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408) }
      let(:err_msg) { { message: 'BTSSS Timeout Error', uuid: } }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(Faraday::TimeoutError)
      end

      it 'logs message and returns an timeout error response' do
        expect(Rails.logger).to receive(:error).with(err_msg)

        response = subject.claim_status(token:, patient_icn:, start_range_date:, end_range_date:)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end
  end

  describe '#submit_claim_v2' do
    let(:token) { 'test-token' }
    let(:patient_identifier) { '123ABC456' }
    let(:patient_identifier_type) { 'edipi' }
    let(:appointment_date) { '2022-09-01' }
    let(:opts) { { patient_identifier:, patient_identifier_type:, appointment_date: } }

    context 'when claims service returns success response' do
      let(:claim_response) do
        {
          value: {
            claimNumber: 'TC202207000011666'
          },
          statusCode: 200
        }
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(claim_response)
      end

      it 'returns claims number' do
        expect(subject.submit_claim_v2(token, opts)).to eq(claim_response)
      end
    end

    context 'when claims service returns a 500 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and returns original error' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim_v2(token, opts)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when claims service returns a 400 error response' do
      let(:resp) do
        Faraday::Response.new(
          body: { error: { currentDate: '[07/29/2022 01:05:41 PM]',
                           message: '07/29/2022 : There were multiple appointments for that date' } }, status: 400
        )
      end
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and returns original error' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim_v2(token, opts)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when claims service returns a 401 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Unauthorized' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and returns original error' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim_v2(token, opts)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when claims service returns a 404 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Not Found' }, status: 404) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and raises exception' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)

        response = subject.submit_claim_v2(token, opts)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when call to claims service times out' do
      let(:resp) { Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408) }
      let(:err_msg) { { message: 'BTSSS Timeout Error', uuid: } }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(Faraday::TimeoutError)
      end

      it 'logs message and raises exception' do
        expect(Rails.logger).to receive(:error).with(err_msg)

        response = subject.submit_claim_v2(token, opts)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end
  end

  describe '#claims_default_header' do
    context 'when environment is non-prod' do
      let(:resp_headers) do
        {
          'Content-Type' => 'application/json',
          'OCP-APIM-Subscription-Key' => 'subscription_key'
        }
      end

      it 'returns single subscription key in headers' do
        with_settings(Settings, vsp_environment: 'staging') do
          with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key: 'subscription_key') do
            expect(subject.send(:claims_default_header)).to eq(resp_headers)
          end
        end
      end
    end

    context 'when environment is prod' do
      let(:resp_headers) do
        {
          'Content-Type' => 'application/json',
          'OCP-APIM-Subscription-Key-E' => 'e_key',
          'OCP-APIM-Subscription-Key-S' => 's_key'
        }
      end

      it 'returns both subscription keys in headers' do
        with_settings(Settings, vsp_environment: 'production') do
          with_settings(Settings.check_in.travel_reimbursement_api_v2,
                        { e_subscription_key: 'e_key', s_subscription_key: 's_key' }) do
            expect(subject.send(:claims_default_header)).to eq(resp_headers)
          end
        end
      end
    end
  end
end
