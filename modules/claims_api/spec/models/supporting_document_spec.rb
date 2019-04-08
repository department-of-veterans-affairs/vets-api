# frozen_string_literal: true

require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe ClaimsApi::SupportingDocument, type: :model do
  describe 'encrypted attribute' do
    it 'should do the thing' do
      expect(subject).to encrypt_attr(:file_data)
    end
  end

  describe '#set_file_data!' do
    it 'should store the filename' do
      attachment = build(:supporting_document)

      attachment.set_file_data!(
        Rack::Test::UploadedFile.new(
          "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
        ),
        'docType',
        'description'
      )
      attachment.save!
      attachment.reload

      expect(attachment.file_data).to have_key('filename')
    end
  end
end
