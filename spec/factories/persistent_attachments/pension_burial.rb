# frozen_string_literal: true

FactoryBot.define do
  factory :pension_burial, class: 'PersistentAttachments::PensionBurial' do
    saved_claim { build(:burial_claim_v2) }

    transient do
      file_path { nil }
    end

    after(:build) do |pension_burial, evaluator|
      file_path = evaluator.file_path || 'spec/fixtures/evss_claim/converted_image.TIF.jpg'

      pension_burial.file = File.open(file_path)
    end
  end

  factory :pension_burial_bad_names, class: 'PersistentAttachments::PensionBurial' do
    saved_claim { build(:burial_claim_bad_names) }

    transient do
      file_path { nil }
    end

    after(:build) do |pension_burial, evaluator|
      file_path = evaluator.file_path || 'spec/fixtures/evss_claim/converted_image.TIF.jpg'

      pension_burial.file = File.open(file_path)
    end
  end
end
