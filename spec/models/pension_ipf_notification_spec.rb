# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionIpfNotification, type: :model do
  let(:pension_ipf_notification) { build(:pension_ipf_notification) }

  describe 'payload encryption' do
    it 'encrypts the payload field' do
      expect(subject).to encrypt_attr(:payload)
    end
  end

  describe 'validations' do
    it 'validates presence of payload' do
      expect_attr_valid(pension_ipf_notification, :payload)
      pension_ipf_notification.payload = nil
      expect_attr_invalid(pension_ipf_notification, :payload, "can't be blank")
    end
  end

  describe '#serialize_payload' do
    let(:payload) do
      { a: 1 }
    end

    it 'serializes payload as json' do
      pension_ipf_notification.payload = payload
      pension_ipf_notification.save!

      expect(pension_ipf_notification.payload).to eq(payload.to_json)
    end
  end
end
