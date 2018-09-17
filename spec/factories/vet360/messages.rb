# frozen_string_literal: true

FactoryBot.define do
  factory :vet360_message, class: 'Vet360::Models::Message' do
    code 'some code'
    key 'some key'
    retryable true
    severity 'INFO'
    text 'some text'
  end
end
