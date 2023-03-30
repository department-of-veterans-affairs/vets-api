# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IdCardAnnouncementSubscription, type: :model do
  describe 'when validating' do
    it 'requires a valid email address' do
      subscription = described_class.new(email: 'invalid')
      expect_attr_invalid(subscription, :email, 'is invalid')
    end

    it 'requires less than 255 characters in an email address' do
      email = "#{'x' * 255}@example.com"
      subscription = described_class.new(email:)
      expect_attr_invalid(subscription, :email, 'is too long (maximum is 255 characters)')
    end

    it 'requires a unique email address' do
      email = 'nonunique@example.com'
      described_class.create(email:)
      subscription = described_class.new(email:)
      expect_attr_invalid(subscription, :email, 'has already been taken')
    end
  end

  describe 'va scope' do
    let!(:va_subscription) { described_class.create(email: 'test@va.gov') }
    let!(:subscription) { described_class.create(email: 'test@example.com') }

    it 'includes records with a @va.gov domain' do
      expect(described_class.va).to include(va_subscription)
    end

    it 'does not include records without a @va.gov domain' do
      expect(described_class.va).not_to include(subscription)
    end
  end

  describe 'non-va scope' do
    let!(:va_subscription) { described_class.create(email: 'test@va.gov') }
    let!(:subscription) { described_class.create(email: 'test@example.com') }

    it 'includes records without a @va.gov domain' do
      expect(described_class.non_va).to include(subscription)
    end

    it 'does not include records with a @va.gov domain' do
      expect(described_class.non_va).not_to include(va_subscription)
    end
  end
end
