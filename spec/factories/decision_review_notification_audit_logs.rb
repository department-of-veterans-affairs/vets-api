# frozen_string_literal: true

FactoryBot.define do
  factory :decision_review_notification_audit_log do
    payload do
      {
        id: '6ba01111-f3ee-4a40-9d04-234asdfb6abab9c',
        reference: 'reference-value',
        to: 'test@test.com',
        status: 'delivered',
        created_at: '2023-01-10T00:04:25.273410Z',
        completed_at: '2023-01-10T00:05:33.255911Z',
        sent_at: '2023-01-10T00:04:25.775363Z',
        notification_type: 'email',
        status_reason: '',
        provider: 'pinpoint'
      }
    end
  end
end
