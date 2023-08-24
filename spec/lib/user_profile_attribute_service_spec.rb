# frozen_string_literal: true

require 'rails_helper'
require 'user_profile_attribute_service'

RSpec.describe UserProfileAttributeService, type: :service do
  describe '#cache_profile_attributes' do
    let(:user) { build(:user, :loa3) }

    it 'creates a UserProfileAttributes object' do
      attribute_id = UserProfileAttributeService.new(user).cache_profile_attributes
      attributes = UserProfileAttributes.find(attribute_id)
      expect(attributes.email).to eq(user.email)
      expect(attributes.icn).to eq(user.icn)
      expect(attributes.first_name).to eq(user.first_name)
      expect(attributes.last_name).to eq(user.last_name)
      expect(attributes.ssn).to eq(user.ssn)
      expect(attributes.flipper_id).to eq(user.flipper_id)
    end
  end
end
