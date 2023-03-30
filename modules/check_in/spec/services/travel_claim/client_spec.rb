# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Client do
  subject { described_class.build(check_in:) }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::V2::Session.build(data: { uuid: }) }

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

      it 'yields to block' do
        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_yield(Faraday::Request.new)

        subject.submit_claim(token: access_token, patient_icn: icn, appointment_date: appt_date)
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
          with_settings(Settings.check_in.travel_reimbursement_api, subscription_key: 'subscription_key') do
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
          with_settings(Settings.check_in.travel_reimbursement_api,
                        { e_subscription_key: 'e_key', s_subscription_key: 's_key' }) do
            expect(subject.send(:claims_default_header)).to eq(resp_headers)
          end
        end
      end
    end
  end
end
