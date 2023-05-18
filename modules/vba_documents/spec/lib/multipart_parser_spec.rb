# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/multipart_parser'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/pdf_inspector'

RSpec.describe VBADocuments::MultipartParser do
  include VBADocuments::Fixtures

  describe '#parse' do
    module FixtureHelper
      class << self
        attr_reader :data_type

        def fetch(fixture, type)
          r_val = fixture.path
          r_val = StringIO.new File.open(r_val, 'rb').read if type.eql? :stringio
          r_val
        end
      end

      @data_type = %i[file stringio].freeze
    end

    context 'multipart_data_type' do
      FixtureHelper.data_type.each do |file_or_stringio|
        it "parses a valid multipart payload #{file_or_stringio}" do
          valid_doc = FixtureHelper.fetch(get_fixture('valid_multipart_pdf.blob'), file_or_stringio)
          result = described_class.parse(valid_doc)

          expect(result.size).to eq(2)
          expect(result).to have_key('metadata')
          expect(result['metadata']).to be_a(String)
          expect(result).to have_key('content')
          expect(result['content']).to be_a(Tempfile)
        end

        it "parses a valid multipart payload with attachments #{file_or_stringio}" do
          valid_doc = FixtureHelper.fetch(get_fixture('valid_multipart_pdf_attachments.blob'), file_or_stringio)
          result = described_class.parse(valid_doc)

          expect(result.size).to eq(3)
          expect(result).to have_key('metadata')
          expect(result['metadata']).to be_a(String)
          expect(result).to have_key('content')
          expect(result['content']).to be_a(Tempfile)
          expect(result).to have_key('attachment1')
          expect(result['attachment1']).to be_a(Tempfile)
        end

        it "raises on a malformed multipart payload #{file_or_stringio}" do
          invalid_doc = FixtureHelper.fetch(get_fixture('invalid_multipart_no_boundary.blob'), file_or_stringio)
          expect { described_class.parse(invalid_doc) }.to raise_error do |error|
            expect(error).to be_a(VBADocuments::UploadError)
            expect(error.code).to eq('DOC101')
          end
        end

        it "raises on a multipart with truncated content #{file_or_stringio}" do
          invalid_doc = FixtureHelper.fetch(get_fixture('invalid_multipart_truncated.blob'), file_or_stringio)
          expect { described_class.parse(invalid_doc) }.to raise_error do |error|
            expect(error).to be_a(VBADocuments::UploadError)
            expect(error.code).to eq('DOC101')
          end
        end

        it "raises on a multipart with non-JSON content #{file_or_stringio}" do
          invalid_doc = FixtureHelper.fetch(get_fixture('invalid_multipart_non_json.blob'), file_or_stringio)
          expect { described_class.parse(invalid_doc) }.to raise_error do |error|
            expect(error).to be_a(VBADocuments::UploadError)
            expect(error.code).to eq('DOC101')
            expect(error.detail).to eq('Unsupported content-type text/html')
          end
        end

        it "raises on a multipart with non-PDF content #{file_or_stringio}" do
          invalid_doc = FixtureHelper.fetch(get_fixture('invalid_multipart_non_pdf.blob'), file_or_stringio)
          expect { described_class.parse(invalid_doc) }.to raise_error do |error|
            expect(error).to be_a(VBADocuments::UploadError)
            expect(error.code).to eq('DOC101')
            expect(error.detail).to eq('Unsupported content-type text/plain')
          end
        end

        it "raises on a multipart with a missing content-type header #{file_or_stringio}" do
          invalid_doc = FixtureHelper.fetch(get_fixture('invalid_multipart_no_contenttype.blob'), file_or_stringio)
          expect { described_class.parse(invalid_doc) }.to raise_error do |error|
            expect(error).to be_a(VBADocuments::UploadError)
            expect(error.code).to eq('DOC101')
            expect(error.detail).to eq('Missing content-type header')
          end
        end

        it "raises on a multipart wtih a missing part name header #{file_or_stringio}" do
          invalid_doc = FixtureHelper.fetch(get_fixture('invalid_multipart_no_partname.blob'), file_or_stringio)
          expect { described_class.parse(invalid_doc) }.to raise_error do |error|
            expect(error).to be_a(VBADocuments::UploadError)
            expect(error.code).to eq('DOC101')
            expect(error.detail).to eq('Missing part name parameter in header')
          end
        end

        it "raises on an empty file #{file_or_stringio}" do
          empty_doc = FixtureHelper.fetch(get_fixture('emptyfile.blob'), file_or_stringio)
          expect { described_class.parse(empty_doc) }.to raise_error(StopIteration)
        end

        it "handles a base64 payload #{file_or_stringio}" do
          valid_doc = FixtureHelper.fetch(get_fixture('base_64_with_attachment'), file_or_stringio)
          result = described_class.parse(valid_doc)

          expect(result.size).to eq(3)
          expect(result).to have_key('metadata')
          expect(result['metadata']).to be_a(String)
          expect(result).to have_key('content')
          expect(result['content']).to be_a(Tempfile)
          expect(result).to have_key('attachment1')
          expect(result['attachment1']).to be_a(Tempfile)
        end

        it "logs base64 decoding progress when handling a base64 payload #{file_or_stringio}" do
          log_prefix = described_class.name

          expect(Rails.logger).to receive(:info).with("#{log_prefix} starting to decode Base64 submission contents")
          expect(Rails.logger).to receive(:info).with("#{log_prefix} finished decoding Base64 submission contents")
          expect(Rails.logger).to receive(:info).with("#{log_prefix} finished writing Base64-decoded file")

          valid_doc = FixtureHelper.fetch(get_fixture('base_64'), file_or_stringio)
          described_class.parse(valid_doc)
        end
      end
    end
  end
end
