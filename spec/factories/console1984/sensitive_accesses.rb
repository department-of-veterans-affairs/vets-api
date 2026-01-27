# frozen_string_literal: true

FactoryBot.define do
  factory :console1984_sensitive_access, class: 'Console1984::SensitiveAccess' do
    association :session, factory: :console1984_session
    justification { 'Required for debugging user issue' }
  end
end
