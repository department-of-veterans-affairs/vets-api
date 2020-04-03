# frozen_string_literal: true

FactoryBot.define do
  factory :higher_level_review_submission, class: 'AppealsApi::HigherLevelReviewSubmission' do
    id { SecureRandom.uuid }
    auth_headers { {} }
    form_data do
      file = File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996.json"
      json = JSON.parse file
      json['data']['attributes']
    end
    file_data do
      attachment = build(:power_of_attorney)

      file = Rack::Test::UploadedFile.new(
        "#{::Rails.root}/modules/appeals_api/spec/fixtures/extras.pdf"
      )

      attachment.set_file_data!(file, 'docType')
      attachment.save!
      attachment.reload

      expect(attachment.file_data).to have_key('filename')
      expect(attachment.file_data).to have_key('doc_type')

      expect(attachment.file_name).to eq(attachment.file_data['filename'])
      expect(attachment.document_type).to eq(attachment.file_data['doc_type'])
    end
  end
end
