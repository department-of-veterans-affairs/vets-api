# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PPIU::Service do
  let(:user) { build(:evss_user) }
  subject { described_class.new(user) }

  describe '#get_payment_information' do
    context 'with a valid evss response' do
      it 'returns a payment information response object' do
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

      it 'logs an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_payment_information.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_payment_information.total')
        expect { subject.get_payment_information }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'with a client error' do
      it 'logs the message to sentry' do
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
end
