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
  let(:parts) { VBADocuments::MultipartParser.parse(valid_doc) }

  describe '#perfect_metadata' do
    subject { perfect_metadata(upload_submission, parts, timestamp) }

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

  describe '#validate_documents' do
    it 'validates a valid PDF' do
      expect { validate_documents(parts) }.not_to raise_error
    end

    context 'with errors' do
      let(:pdf_validator_options) { {} }
      let(:error) do
        raised_error = nil
        begin
          validate_documents(parts, pdf_validator_options)
        rescue => e
          raised_error = e
        end
        raised_error
      end

      before do
        expect(error).to be_instance_of(VBADocuments::UploadError)
      end

      describe 'when the page size exceeds the height and width limits' do
        let(:pdf_validator_options) { { width_limit_in_inches: 1, height_limit_in_inches: 1 } }

        it 'raises the correct UploadError' do
          expect(error.code).to eq('DOC108')
          expect(error.detail).to eq('Maximum page size exceeded. Limit is 1 in x 1 in.')
          expect(error.message).to eq(error.detail)
        end
      end

      describe 'when the file size exceeds the limit' do
        let(:pdf_validator_options) { { size_limit_in_bytes: 1_000 } }

        it 'raises the correct UploadError' do
          expect(error).to be_instance_of(VBADocuments::UploadError)
          expect(error.code).to eq('DOC106')
          expect(error.detail).to eq('Maximum document size exceeded. Limit is 1 KB per document.')
          expect(error.message).to eq(error.detail)
        end
      end
    end
  end
end
