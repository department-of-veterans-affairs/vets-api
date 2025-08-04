# frozen_string_literal: true

FactoryBot.define do
  factory :claim_evidence, class: 'PersistentAttachments::ClaimEvidence' do
    transient do
      file_path { nil }
    end

    after(:build) do |claim_evidence, evaluator|
      # Using a JPG because a PDF causes:
      #   SHRINE WARNING: Error occurred when attempting to extract image dimensions:
      #   <FastImage::UnknownImageType: FastImage::UnknownImageType>
      file_path = evaluator.file_path || 'spec/fixtures/files/doctors-note.jpg'

      claim_evidence.file = File.open(file_path)
    end
  end
end
