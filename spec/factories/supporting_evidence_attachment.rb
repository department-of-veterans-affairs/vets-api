# frozen_string_literal: true

FactoryBot.define do
  factory :supporting_evidence_attachment, class: 'SupportingEvidenceAttachment' do
    trait :with_file_data do
      after(:build) do |supporting_evidence_attachment|
        supporting_evidence_attachment.set_file_data!(
          Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf'), 'application/pdf')
        )
      end
    end
  end
end
