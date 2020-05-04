# frozen_string_literal: true

require 'rails_helper'

describe VeteranVerification::DisabilityRating do
  let(:user) { build(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3)) }

  describe '#formatted_ratings' do
    it 'returns overall rating and list of ratings' do
      VCR.use_cassette('bgs/rating_web_service/rating_data') do
        result = described_class.for_user(user)
        expect(result[:overall_disability_rating]).to eq('100')
        expect(result[:ratings][0][:decision]).to eq('Service Connected')
        expect(result[:ratings][0][:effective_date]).to eq('01012005')
        expect(result[:ratings][0][:rating_percentage]).to eq('100')
      end
    end

    it 'returns overall rating and one rating' do
      VCR.use_cassette('bgs/rating_web_service/rating_data_single_rating') do
        result = described_class.for_user(user)
        expect(result[:overall_disability_rating]).to eq('100')
        expect(result[:ratings][0][:decision]).to eq('Service Connected')
        expect(result[:ratings][0][:effective_date]).to eq('01012005')
        expect(result[:ratings][0][:rating_percentage]).to eq('100')
      end
    end

    it 'record has no ratings' do
      VCR.use_cassette('bgs/rating_web_service/rating_data_no_ratings') do
        result = described_class.for_user(user)
        expect(result[:overall_disability_rating]).to eq('100')
      end
    end
  end
end
