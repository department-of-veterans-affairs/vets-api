# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DecisionReviewNotificationAuditLog, type: :model do
  let(:audit_log) { build(:decision_review_notification_audit_log) }

  describe 'payload encryption' do
    it 'encrypts the payload field' do
      expect(subject).to encrypt_attr(:payload)
    end
  end

  describe 'validations' do
    it 'validates presence of payload' do
      expect_attr_valid(audit_log, :payload)
      audit_log.payload = nil
      expect_attr_invalid(audit_log, :payload, "can't be blank")
    end
  end

  describe '#serialize_payload' do
    let(:payload) do
      { a: 1 }
    end

    it 'serializes payload as json' do
      audit_log.payload = payload
      audit_log.save!

      expect(audit_log.payload).to eq(payload.to_json)
    end
  end
end
