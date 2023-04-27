# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/pdf_inspector'

RSpec.describe VBADocuments::PDFInspector do
  include VBADocuments::Fixtures

  let(:valid_doc) { get_fixture('valid_multipart_pdf_attachments.blob').path }

  context 'when initialized with a valid multipart payload with attachment and add_file_key: false' do
    before do
      @inspector = described_class.new(pdf: valid_doc, add_file_key: false)
    end

    describe '#pdf_data' do
      subject { @inspector.pdf_data }

      let(:sha256_char_length) { 64 }
      let(:page_height) { 11.0 }
      let(:page_width) { 8.5 }

      it 'returns a hash' do
        expect(subject).to be_a(Hash)
      end

      it 'does not have the file key' do
        expect(subject).not_to have_key(valid_doc)
      end

      it 'has all expected keys' do
        expected_keys = {
          pdf_keys: [%i[source doc_type total_documents total_pages content], subject],
          content_keys: [%i[page_count dimensions sha256_checksum attachments], subject[:content]],
          content_dimension_keys: [%i[height width oversized_pdf], subject[:content][:dimensions]],
          attachment_keys: [%i[page_count dimensions sha256_checksum], subject[:content][:attachments][0]],
          attachment_dimension_keys: [%i[height width oversized_pdf], subject[:content][:attachments][0][:dimensions]]
        }

        expected_keys.each_key do |key|
          has_all_keys = expected_keys[key][0].all? { |s| expected_keys[key][1].key? s }
          msg = "Key Check error on:  #{key}"
          expect(has_all_keys).to eq(true), msg
        end
      end

      it 'has the correct document totals' do
        expect(subject[:total_pages]).to eq(2)
        expect(subject[:total_documents]).to eq(2)
      end

      it 'has the correct content data' do
        content_hash = subject[:content]

        expect(content_hash[:dimensions]).to be_a(Hash)
        expect(content_hash[:dimensions][:height]).to eq(page_height)
        expect(content_hash[:dimensions][:width]).to eq(page_width)
        expect(content_hash[:dimensions][:oversized_pdf]).to eq(false)
        expect(content_hash[:page_count]).to eq(1)
        expect(content_hash[:sha256_checksum]).to be_a(String)
        expect(content_hash[:sha256_checksum].length).to eq(sha256_char_length)
      end

      it 'has the correct attachment data' do
        attachments = subject[:content][:attachments]
        attachment_hash = attachments[0]

        expect(attachments).to be_a(Array)
        expect(attachments.count).to eq(1)
        expect(attachment_hash[:dimensions]).to be_a(Hash)
        expect(attachment_hash[:dimensions][:height]).to eq(page_height)
        expect(attachment_hash[:dimensions][:width]).to eq(page_width)
        expect(attachment_hash[:dimensions][:oversized_pdf]).to eq(false)
        expect(attachment_hash[:page_count]).to eq(1)
        expect(attachment_hash[:sha256_checksum]).to be_a(String)
        expect(attachment_hash[:sha256_checksum].length).to eq(sha256_char_length)
      end
    end

    context 'when initialized with a valid multipart payload with attachment and add_file_key: true' do
      before do
        @inspector = described_class.new(pdf: valid_doc, add_file_key: true)
      end

      describe '#pdf_data' do
        subject { @inspector.pdf_data }

        it 'returns a hash' do
          expect(subject).to be_a(Hash)
        end

        it 'has the file key' do
          expect(subject).to have_key(valid_doc)
        end
      end
    end
  end
end
