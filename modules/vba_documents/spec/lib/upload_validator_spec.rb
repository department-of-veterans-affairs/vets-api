# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/upload_validator'
require 'vba_documents/multipart_parser'

RSpec.describe VBADocuments::UploadValidations do
  include VBADocuments::Fixtures
  include VBADocuments::UploadValidations

  let(:valid_doc) { get_fixture('valid_multipart_pdf_attachments.blob').path }
  let(:upload_submission) { FactoryBot.create(:upload_submission, :status_uploaded) }
  let(:timestamp) { DateTime.now }

  describe '.perfect_metadata' do
    subject { perfect_metadata(upload_submission, @parts, timestamp) }

    before do
      @parts = VBADocuments::MultipartParser.parse(valid_doc)
    end

    it 'returns a hash' do
      expect(subject).to be_a(Hash)
    end

    it 'has the content SHA-256 checksum' do
      expect(subject).to have_key('hashV')
      expect(subject['hashV']).to eq(upload_submission.uploaded_pdf['content']['sha256_checksum'])
    end

    it 'has the attachment SHA-256 checksum' do
      expect(subject).to have_key('ahash1')
      expect(subject['ahash1']).to eq(upload_submission.uploaded_pdf['content']['attachments'][0]['sha256_checksum'])
    end
  end
end
