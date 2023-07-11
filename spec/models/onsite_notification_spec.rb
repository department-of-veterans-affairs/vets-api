# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnsiteNotification, type: :model do
  let(:onsite_notification) { described_class.new }

  describe 'validations' do
    it 'validates presence of template_id' do
      expect_attr_invalid(onsite_notification, :template_id, "can't be blank")
      onsite_notification.template_id = 'f9947b27-df3b-4b09-875c-7f76594d766d'
      expect_attr_valid(onsite_notification, :template_id)
    end

    it 'validates presence of va_profile_id' do
      expect_attr_invalid(onsite_notification, :va_profile_id, "can't be blank")
      onsite_notification.va_profile_id = '123'
      expect_attr_valid(onsite_notification, :va_profile_id)
    end

    it 'validates inclusion of template_id' do
      onsite_notification.template_id = '123'
      expect_attr_invalid(onsite_notification, :template_id, 'is not included in the list')
      onsite_notification.template_id = 'f9947b27-df3b-4b09-875c-7f76594d766d'
      expect_attr_valid(onsite_notification, :template_id)
      onsite_notification.template_id = '7efc2b8b-e59a-4571-a2ff-0fd70253e973'
      expect_attr_valid(onsite_notification, :template_id)
    end
  end

  describe '.for_user' do
    let(:user) { create(:user, :loa3) }

    before do
      @n1 = create(:onsite_notification, va_profile_id: user.vet360_id)
      @n2 = create(:onsite_notification, va_profile_id: user.vet360_id)
      @n3 = create(:onsite_notification, va_profile_id: user.vet360_id)
      @n4 = create(:onsite_notification, dismissed: true, va_profile_id: user.vet360_id)
    end

    it 'returns non-dismissed onsite_notifications for the user' do
      notifications = described_class.for_user(user)

      expect(notifications.count).to eq(3)
      notifications.each do |notification|
        expect(notification.dismissed).to be(false)
      end
    end

    it 'returns all onsite_notifications for the user, including dismissed ones' do
      notifications = described_class.for_user(user, include_dismissed: true)

      expect(notifications.count).to eq(4)
    end

    it 'returns onsite_notifications for the user in descending order' do
      notifications = described_class.for_user(user)
      notifications.zip([@n3, @n2, @n1]).each do |actual, expected|
        expect(actual.created_at).to eq(expected.created_at)
      end
    end
  end
end
