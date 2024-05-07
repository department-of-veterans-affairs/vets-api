# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranOnboarding, type: :model do
  describe 'validations' do
    it 'validates presence of user_account_uuid' do
      subject = described_class.new(user_account_uuid: nil)
      expect(subject).not_to be_valid
      expect(subject.errors.details[:user_account_uuid]).to include(error: :blank)
    end

    it 'validates uniqueness of user_account_uuid' do
      described_class.create!(user_account_uuid: '123')
      subject = described_class.new(user_account_uuid: '123')
      expect(subject).not_to be_valid
      expect(subject.errors.details[:user_account_uuid]).to include(error: :taken, value: '123')
    end
  end

  describe '#show_onboarding_flow_on_login' do
    it 'returns the value of display_onboarding_flow' do
      subject = described_class.new(display_onboarding_flow: true)
      expect(subject.show_onboarding_flow_on_login).to be_truthy
    end
  end
end
