require 'rails_helper'

describe HCA::RateLimitedSearch do
  describe '.combine_traits' do
    it 'should combine non-ssn user attributes' do
      user_attributes = HealthCareApplication.user_attributes(create(:health_care_application).parsed_form)
      expect(described_class.combine_traits(user_attributes)).to eq(
        'firstnamezztest1923-01-02f'
      )
    end
  end
end
