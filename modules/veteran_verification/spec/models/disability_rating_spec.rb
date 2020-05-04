# frozen_string_literal: true

require 'rails_helper'

describe VeteranVerification::DisabilityRating do
  let(:user) { build(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3)) }

  describe '#formatted_episodes' do
    it 'returns service history and deployments' do
      VCR.use_cassette('bgs/rating_web_service/rating_data') do
        result = described_class.for_user(user)
        expect(result[:overall_disability_rating]).to eq('100')
        expect(result[:ratings][0][:decision]).to eq('Service Connected')
        expect(result[:ratings][0][:effective_date]).to eq('01012005')
        expect(result[:ratings][0][:rating_percentage]).to eq('100')
      end
    end
  end
end
