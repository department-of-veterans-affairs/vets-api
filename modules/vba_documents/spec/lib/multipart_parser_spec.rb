# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/multipart_parser'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/pdf_inspector'

RSpec.describe VBADocuments::MultipartParser do
  include VBADocuments::Fixtures

  describe '#parse' do
    it 'parses a valid multipart payload' do
      valid_doc = get_fixture('valid_multipart_pdf.blob').path
      result = described_class.parse(valid_doc)
      expect(result.size).to eq(2)
      expect(result).to have_key('metadata')
      expect(result['metadata']).to be_a(String)
      expect(result).to have_key('content')
      expect(result['content']).to be_a(Tempfile)
    end

    it 'parses a valid multipart payload with attachments' do
      valid_doc = get_fixture('valid_multipart_pdf_attachments.blob').path
      result = described_class.parse(valid_doc)
      expect(result.size).to eq(3)
      expect(result).to have_key('metadata')
      expect(result['metadata']).to be_a(String)
      expect(result).to have_key('content')
      expect(result['content']).to be_a(Tempfile)
      expect(result).to have_key('attachment1')
      expect(result['attachment1']).to be_a(Tempfile)
    end

    it 'the inspector can parse a valid multipart payload with attachments and return metadata' do
      valid_doc = get_fixture('valid_multipart_pdf_attachments.blob').path
      inspector = VBADocuments::PDFInspector.new(pdf: valid_doc, add_file_key: true)
      data = inspector.pdf_data
      expect(data).to be_a(Hash)
      expect(data.keys[0]).to eq(valid_doc)
      doc_hash = data[valid_doc]
      has_all_keys = %i[source doc_type page_count total_documents total_pages dimensions oversized_pdf attachments].all? {|s| doc_hash.key? s}
      expect(has_all_keys).to eq(true)
      expect(doc_hash[:dimensions]).to be_a(Hash)
      expect(doc_hash[:dimensions]).to have_key(:height)
      expect(doc_hash[:dimensions]).to have_key(:width)
      expect(doc_hash[:dimensions][:height]).to eq(8.5)
      expect(doc_hash[:dimensions][:width]).to eq(11.0)
      expect(doc_hash[:page_count]).to eq(1)
      expect(doc_hash[:total_pages]).to eq(2)
      expect(doc_hash[:total_documents]).to eq(2)
      expect(doc_hash[:oversized_pdf]).to eq(false)
      expect(doc_hash[:attachments]).to be_a(Array)
      expect(doc_hash[:attachments].count).to eq(1)


      # Load the inspector without adding the file key. This is used to save the data to the database
      inspector = VBADocuments::PDFInspector.new(pdf: valid_doc, add_file_key: false)
      data = inspector.pdf_data
      expect(data).not_to have_key(valid_doc)
    end

    it 'raises on a malformed multipart payload' do
      invalid_doc = get_fixture('invalid_multipart_no_boundary.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
      end
    end

    it 'raises on a multipart with truncated content' do
      invalid_doc = get_fixture('invalid_multipart_truncated.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
      end
    end

    it 'raises on a multipart with non-JSON content' do
      invalid_doc = get_fixture('invalid_multipart_non_json.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
        expect(error.detail).to eq('Unsupported content-type text/html')
      end
    end

    it 'raises on a multipart with non-PDF content' do
      invalid_doc = get_fixture('invalid_multipart_non_pdf.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
        expect(error.detail).to eq('Unsupported content-type text/plain')
      end
    end

    it 'raises on a multipart with a missing content-type header' do
      invalid_doc = get_fixture('invalid_multipart_no_contenttype.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
        expect(error.detail).to eq('Missing content-type header')
      end
    end

    it 'raises on a multipart wtih a missing part name header' do
      invalid_doc = get_fixture('invalid_multipart_no_partname.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
        expect(error.detail).to eq('Missing part name parameter in header')
      end
    end

    it 'raises on an empty payload' do
      empty_doc = get_fixture('emptyfile.blob').path
      expect { described_class.parse(empty_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC107')
        expect(error.detail).to eq('Empty payload')
      end
    end

    it 'handles a base64 payload' do
      valid_doc = get_fixture('base_64').path
      result = described_class.parse(valid_doc)
      expect(result.size).to eq(2)
      expect(result).to have_key('metadata')
      expect(result['metadata']).to be_a(String)
      expect(result).to have_key('content')
      expect(result['content']).to be_a(Tempfile)
    end
  end
end
