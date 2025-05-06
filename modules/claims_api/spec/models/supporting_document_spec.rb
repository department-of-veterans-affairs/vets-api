# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SupportingDocument, type: :model do
  describe 'encrypted attribute' do
    it 'does the thing' do
      expect(subject).to encrypt_attr(:file_data)
    end
  end

  describe '#set_file_data!' do
    it 'stores the file_data and give me a full evss document' do
      attachment = build(:supporting_document)

      file = Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      )
      attachment.set_file_data!(file, 'docType', 'description')
      attachment.save!
      attachment.reload

      expect(attachment.file_data).to have_key('filename')
      expect(attachment.file_data).to have_key('doc_type')
      expect(attachment.file_data).to have_key('description')

      expect(attachment.tracked_item_id).to eq(attachment.id)
      expect(attachment.file_name).to eq(attachment.file_data['filename'])
      expect(attachment.document_type).to eq(attachment.file_data['doc_type'])
      expect(attachment.description).to eq(attachment.file_data['description'])
    end
  end
end
