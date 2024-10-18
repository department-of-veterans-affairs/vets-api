# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/callback_class'

describe VANotify::StatusUpdate do
  let(:notification_id) { SecureRandom.uuid }

  describe '#delegate' do
    it 'returns the callback klass' do
      create(:notification, notification_id:, callback: 'OtherTeam::OtherForm')
      provider_callback = {
        id: notification_id,
        reference: '',
        to: '',
        status: 'delivered',
        created_at: '2024-01-10T00:04:25.273410Z',
        completed_at: '2024-01-10T00:05:33.255911Z',
        sent_at: '2024-01-10T00:04:25.775363Z',
        notification_type: 'Email',
        status_reason: 'delivered',
        provider: 'pinpoint'
      }

      received_callback = described_class.new.delegate(provider_callback)

      expect(received_callback).to be_an_instance_of(VANotify::Notification)
    end
  end
end
