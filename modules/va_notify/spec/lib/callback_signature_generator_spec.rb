# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/callback_signature_generator'

describe VANotify::CallbackSignatureGenerator do
  describe '#call' do
    it 'creates a signature' do
      payload = {
        id: '123',
        reference: nil,
        to: 'test@example.com',
        status: 'delivered',
        created_at: '2025-08-12T18:20:31.917125Z',
        completed_at: '2025-08-12T18:20:35.890510Z',
        sent_at: '2025-08-12T18:20:32.325383Z',
        notification_type: 'email',
        status_reason: nil,
        provider: 'ses',
        provider_payload: nil
      }.to_json
      api_key = 'test_api_key'
      signature = described_class.call(payload, api_key)
      expect(signature).to eq('aee3be8e2b10cf83668cbd2546a38d33eeff4d95da1df1e99011fb5e24f03910')
    end
  end
end
