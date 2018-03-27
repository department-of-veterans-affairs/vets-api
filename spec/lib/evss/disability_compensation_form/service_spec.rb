# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/service'

describe EVSS::DisabilityCompensationForm::Service do
  
  describe '#get_rated_disabilities' do
    let(:user) { build(:rated_disabilities_user) }
    subject { described_class.new(user) }

    context 'with a valid evss response' do
      it 'returns a rated disabilities response object' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          response = subject.get_rated_disabilities
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::RatedDisabilitiesResponse
          expect(response.rated_disabilities.count).to eq 2
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      end

      it 'should log an error and raise GatewayTimeout' do
        expect(Rails.logger).to receive(:error).with(/Timeout/)
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_rated_disabilities.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_rated_disabilities.total')
        expect { subject.get_rated_disabilities }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe '#submit_form' do
  end
end
