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
    end
  end

  describe '.for_user' do
    let(:user) { create(:user, :loa3) }
    let!(:onsite_notification) { create(:onsite_notification, va_profile_id: user.vet360_id) }

    before do
      create(:onsite_notification, dismissed: true, va_profile_id: user.vet360_id)
      create(:onsite_notification)
    end

    it 'returns non-dismissed onsite_notifications for the user' do
      expect(described_class.for_user(user)).to eq([onsite_notification])
    end
  end
end
