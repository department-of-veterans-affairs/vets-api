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
end
