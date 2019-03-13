# frozen_string_literal: true

require 'rails_helper'

describe HCA::RateLimitedSearch do
  let(:user_attributes) { HealthCareApplication.user_attributes(create(:health_care_application).parsed_form) }

  describe '.combine_traits' do
    it 'should combine non-ssn user attributes' do
      expect(described_class.combine_traits(user_attributes)).to eq(
        'firstnamezztest1923-01-02'
      )
    end
  end

  describe('.truncate_ssn') do
    it 'should get the first 3 and last 4 of the ssn' do
      expect(described_class.truncate_ssn('111551234')).to eq(
        '1111234'
      )
    end
  end

  describe '.create_rate_limited_searches' do
    it 'should create rate limited search models' do
      described_class.create_rate_limited_searches(user_attributes)
      %w[ssn:1111234 traits:firstnamezztest1923-01-02].each do |key|
        expect(RateLimitedSearch.find(Digest::SHA2.hexdigest(key)).count).to eq(1)
      end
    end
  end
end
