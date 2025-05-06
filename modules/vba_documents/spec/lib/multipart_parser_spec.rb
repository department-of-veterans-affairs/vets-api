# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/multipart_parser'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/pdf_inspector'

RSpec.describe VBADocuments::MultipartParser do
  include VBADocuments::Fixtures

  describe '#parse' do
    it 'successfully parses a valid multipart payload' do
      valid_doc = get_fixture('valid_multipart_pdf.blob').path
      result = described_class.parse(valid_doc)

      expect(result.size).to eq(2)
      expect(result).to have_key('metadata')
      expect(result['metadata']).to be_a(String)
      expect(result).to have_key('content')
      expect(result['content']).to be_a(Tempfile)
    end

    it 'successfully parses a valid multipart payload with attachments' do
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

    it 'raises on a malformed multipart payload' do
      invalid_doc = get_fixture('invalid_multipart_no_boundary.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
        expect(error.detail).to eq('Unexpected end of payload')
      end
    end

    it 'raises on a multipart with truncated content' do
      invalid_doc = get_fixture('invalid_multipart_truncated.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
        expect(error.detail).to eq('Unexpected end of payload')
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

    it 'raises on a multipart with a missing part name header' do
      invalid_doc = get_fixture('invalid_multipart_no_partname.blob').path
      expect { described_class.parse(invalid_doc) }.to raise_error do |error|
        expect(error).to be_a(VBADocuments::UploadError)
        expect(error.code).to eq('DOC101')
        expect(error.detail).to eq('Missing part name parameter in header')
      end
    end

    it 'raises on an empty file' do
      empty_doc = get_fixture('emptyfile.blob').path
      expect { described_class.parse(empty_doc) }.to raise_error(StopIteration)
    end

    it 'handles a base64 payload' do
      valid_doc = get_fixture('base_64_with_attachment').path
      result = described_class.parse(valid_doc)

      expect(result.size).to eq(3)
      expect(result).to have_key('metadata')
      expect(result['metadata']).to be_a(String)
      expect(result).to have_key('content')
      expect(result['content']).to be_a(Tempfile)
      expect(result).to have_key('attachment1')
      expect(result['attachment1']).to be_a(Tempfile)
    end

    it 'logs base64 decoding progress when handling a base64 payload' do
      log_prefix = described_class.name

      expect(Rails.logger).to receive(:info).with("#{log_prefix} starting to decode Base64 submission contents")
      expect(Rails.logger).to receive(:info).with("#{log_prefix} finished decoding Base64 submission contents")
      expect(Rails.logger).to receive(:info).with("#{log_prefix} finished writing Base64-decoded file")

      valid_doc = get_fixture('base_64').path
      described_class.parse(valid_doc)
    end

    context 'when vba_documents_virus_scan feature flag is enabled' do
      before { expect(Flipper).to receive(:enabled?).with(:vba_documents_virus_scan).and_return(true) }

      it 'successfully parses the payload when no virus is found' do
        expect(Common::VirusScan).to receive(:scan).and_return(true)

        valid_doc = get_fixture('valid_multipart_pdf.blob').path
        described_class.parse(valid_doc)
      end

      it 'raises when a virus is found' do
        expect(Common::VirusScan).to receive(:scan).and_return(false)

        valid_doc = get_fixture('valid_multipart_pdf.blob').path
        expect { described_class.parse(valid_doc) }.to raise_error do |error|
          expect(error).to be_a(VBADocuments::UploadError)
          expect(error.code).to eq('DOC101')
          expect(error.detail).to eq('Virus detected in submission')
        end
      end
    end

    context 'when vba_documents_virus_scan feature flag is not enabled' do
      before { expect(Flipper).to receive(:enabled?).with(:vba_documents_virus_scan).and_return(false) }

      it 'does not perform a virus scan on the payload' do
        expect(Common::FileHelpers).not_to receive(:generate_clamav_temp_file)
        expect(Common::VirusScan).not_to receive(:scan)

        valid_doc = get_fixture('valid_multipart_pdf.blob').path
        described_class.parse(valid_doc)
      end
    end
  end
end
