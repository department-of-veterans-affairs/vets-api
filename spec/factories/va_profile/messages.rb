# frozen_string_literal: true

FactoryBot.define do
  factory :va_profile_message, class: 'VAProfile::Models::Message' do
    code { 'some code' }
    key { 'some key' }
    retryable { true }
    severity { 'INFO' }
    text { 'some text' }
  end
end
