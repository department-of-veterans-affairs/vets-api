# frozen_string_literal: true
require 'rails_helper'

RSpec.describe IdCardAnnouncementSubscription, type: :model do
  describe 'when validating' do
    it 'requires a valid email address' do
      subscription = described_class.new(email: 'invalid')
      expect_attr_invalid(subscription, :email, 'is invalid')
    end

    it 'requires a unique email address' do
      email = 'nonunique@example.com'
      described_class.create(email: email)
      subscription = described_class.new(email: email)
      expect_attr_invalid(subscription, :email, 'has already been taken')
    end
  end
end
