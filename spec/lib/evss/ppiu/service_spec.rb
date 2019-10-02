# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PPIU::Service do
  let(:user) { build(:evss_user) }

  subject { described_class.new(user) }

  describe '#get_payment_information' do
    context 'with a valid evss response' do
      it 'returns a payment information response object', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/payment_information') do
          response = subject.get_payment_information
          expect(response).to be_ok
          expect(response).to be_an EVSS::PPIU::PaymentInformationResponse
          expect(response.responses.first.control_information)
            .to be_an EVSS::PPIU::ControlInformation
          expect(response.responses.first.payment_account)
            .to be_an EVSS::PPIU::PaymentAccount
          expect(response.responses.first.payment_address)
            .to be_an EVSS::PPIU::PaymentAddress
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      end

      it 'logs an error and raise GatewayTimeout', :aggregate_failures do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_payment_information.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_payment_information.total')
        expect { subject.get_payment_information }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'with a client error' do
      it 'logs the message to sentry', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/service_error') do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_payment_information.fail', tags: ['error:Common::Client::Errors::ClientError', 'status:500']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_payment_information.total')
          expect { subject.get_payment_information }.to raise_error(EVSS::PPIU::ServiceException)
        end
      end
    end
  end

  describe '#update_payment_information' do
    let(:request_payload) do
      {
        'accountType' => 'Checking',
        'financialInstitutionName' => 'Fake Bank Name',
        'accountNumber' => '1234',
        'financialInstitutionRoutingNumber' => '021000021'
      }
    end

    context 'with a valid a valid evss response' do
      it 'returns a payment information response object', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          response = subject.update_payment_information(request_payload)
          expect(response).to be_ok
          expect(response).to be_an EVSS::PPIU::PaymentInformationResponse
          expect(response.responses.first.control_information)
            .to be_an EVSS::PPIU::ControlInformation
          expect(response.responses.first.payment_account)
            .to be_an EVSS::PPIU::PaymentAccount
          expect(response.responses.first.payment_address)
            .to be_an EVSS::PPIU::PaymentAddress
        end
      end
    end

    context 'with a nil value for `financial_institution_name`' do
      before do
        request_payload['financial_institution_name'] = nil
      end

      it 'returns a payment information response object', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          response = subject.update_payment_information(request_payload)
          expect(response).to be_ok
          expect(response).to be_an EVSS::PPIU::PaymentInformationResponse
          expect(response.responses.first.control_information)
            .to be_an EVSS::PPIU::ControlInformation
          expect(response.responses.first.payment_account)
            .to be_an EVSS::PPIU::PaymentAccount
          expect(response.responses.first.payment_address)
            .to be_an EVSS::PPIU::PaymentAddress
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'logs an error and raise GatewayTimeout', :aggregate_failures do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.update_payment_information.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.update_payment_information.total')
        expect { subject.update_payment_information(request_payload) }.to raise_error(
          Common::Exceptions::GatewayTimeout
        )
      end
    end

    context 'with a client error' do
      it 'logs the message to sentry', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_service_error') do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.update_payment_information.fail', tags: [
              'error:Common::Client::Errors::ClientError', 'status:500'
            ]
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.update_payment_information.total')
          expect { subject.update_payment_information(request_payload) }.to raise_error(EVSS::PPIU::ServiceException)
        end
      end
    end
  end
end
