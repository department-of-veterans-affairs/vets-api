# frozen_string_literal: true

FactoryBot.define do
  factory :debts_api_digital_dispute_submission, class: 'DebtsApi::V0::DigitalDisputeSubmission' do
    user_uuid { SecureRandom.uuid }
    guid { SecureRandom.uuid }
    association :user_account, factory: :user_account
    state { :pending }

    after(:build) do |submission|
      submission.files.attach(
        io: Rails.root.join('spec', 'fixtures', 'pdf_fill', '686C-674-V2', 'tester.pdf').open,
        filename: 'sample.pdf',
        content_type: 'application/pdf'
      )
    end
  end
end
