# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NodNotification, type: :model do
  let(:nod_notification) { build(:nod_notification) }

  describe 'payload encryption' do
    it 'encrypts the payload field' do
      expect(subject).to encrypt_attr(:payload)
    end
  end

  describe 'validations' do
    it 'validates presence of payload' do
      expect_attr_valid(nod_notification, :payload)
      nod_notification.payload = nil
      expect_attr_invalid(nod_notification, :payload, "can't be blank")
    end
  end

  describe '#serialize_payload' do
    let(:payload) do
      { a: 1 }
    end

    it 'serializes payload as json' do
      nod_notification.payload = payload
      nod_notification.save!

      expect(nod_notification.payload).to eq(payload.to_json)
    end
  end
end
