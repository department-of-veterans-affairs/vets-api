# frozen_string_literal: true

FactoryBot.define do
  factory :audit_data, class: 'InheritedProofing::AuditData' do
    user_uuid { SecureRandom.uuid }
    code { SecureRandom.hex }
    legacy_csp { 'mhv' }
  end
end
