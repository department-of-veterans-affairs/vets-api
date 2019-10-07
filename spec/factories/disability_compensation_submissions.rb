# frozen_string_literal: true

FactoryBot.define do
  factory :disability_compensation_submission, class: 'DisabilityCompensationSubmission' do
    disability_compensation_id { 123 }
    va526ez_submit_transaction_id { 123 }
    complete { false }
  end
end
