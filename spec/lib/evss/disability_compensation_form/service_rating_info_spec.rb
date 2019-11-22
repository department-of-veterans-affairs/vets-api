# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/service_rating_info'

describe EVSS::DisabilityCompensationForm::ServiceRatingInfo do
  subject do
    described_class.new(
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    )
  end

  let(:user) { build(:disabilities_compensation_user) }

  describe '#get_rating_info' do
    context 'with a valid evss response' do
      it 'returns a rating info response object' do
        VCR.use_cassette('evss/disability_compensation_form/find_rating_info_pid') do
          response = subject.get_rating_info
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::RatingInfoResponse
          expect(response.user_percent_of_disability).to be_an String
          expect(response.user_percent_of_disability).to eq ""
        end
      end
    end
=begin
    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      end

      it 'logs an error and raise GatewayTimeout' do
        expect(StatsD).to receive(:increment).once.with(
          'api.evss.get_rating_info.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.evss.get_rating_info.total')
        expect { subject.get_rating_info }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
=end
  end
end
