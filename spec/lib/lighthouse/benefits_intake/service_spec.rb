# frozen_string_literal: true

require 'rails_helper'
require 'common/file_helpers'
require 'lighthouse/benefits_intake/service'
require 'pdf_utilities/pdf_validator'

RSpec.describe BenefitsIntake::Service do
  let(:service) { BenefitsIntake::Service.new }
  let(:metadata) do
    {
      'veteranFirstName' => 'firstname',
      'veteranLastName' => 'lastname',
      'fileNumber' => '123456789',
      'zipCode' => '12345-5555',
      'source' => 'source',
      'docType' => 'doc_type',
      'businessLine' => 'BVA'
    }
  end
  let(:upload) do
    OpenStruct.new({
                     body: {
                       'data' => {
                         'id' => 'uuid-for-the-upload',
                         'attributes' => {
                           'location' => 'upload-url-location'
                         }
                       }
                     }
                   })
  end
  let(:mime_pdf) { Mime[:pdf].to_s }
  let(:mime_json) { Mime[:json].to_s }

  before do
    allow(service).to receive(:perform)
  end

  describe '#perform_upload' do
    let(:args) do
      {
        metadata: metadata.to_json,
        document: 'file-path',
        attachments: %w[attachment-path1 attachment-path2]
        # upload_url: nil, # force call to #request_upload
      }
    end

    let(:expected_params) do
      {
        metadata: 'a-file-io-object',
        content: 'a-file-io-object',
        attachment1: 'a-file-io-object',
        attachment2: 'a-file-io-object'
      }
    end

    let(:headers) { { 'Content-Type' => 'multipart/form-data' } }

    before do
      service.instance_variable_set(:@uploads, true)
      service.instance_variable_set(:@location, 'location')
      service.instance_variable_set(:@uuid, 'uuid')

      allow(Common::FileHelpers).to receive(:generate_random_file).and_return 'a-temp-file'
    end

    it 'performs the upload' do
      allow(Faraday::UploadIO).to receive(:new).and_return 'a-file-io-object'

      expect(service).to receive(:check_upload_size)
      expect(Common::FileHelpers).to receive(:generate_random_file).once.with(metadata.to_json)

      expect(Faraday::UploadIO).to receive(:new).once.with('a-temp-file', mime_json, 'metadata.json')
      expect(Faraday::UploadIO).to receive(:new).once.with('file-path', mime_pdf, 'file-path')
      expect(Faraday::UploadIO).to receive(:new).once.with('attachment-path1', mime_pdf, 'attachment-path1')
      expect(Faraday::UploadIO).to receive(:new).once.with('attachment-path2', mime_pdf, 'attachment-path2')

      expect(service).to receive(:perform).with(:put, 'location', expected_params, headers)
      service.perform_upload(**args)
    end

    it 'performs the upload to a different url' do
      args[:upload_url] = 'another-location'
      allow(Faraday::UploadIO).to receive(:new).and_return 'a-file-io-object'

      expect(service).to receive(:check_upload_size)
      expect(service).not_to receive(:request_upload)
      expect(service).to receive(:perform).with(:put, 'another-location', expected_params, headers)
      service.perform_upload(**args)
    end

    it 'errors on invalid JSON metadata' do
      args[:metadata] = 'not a json string'

      expect(Common::FileHelpers).not_to receive(:generate_random_file)
      expect(service).not_to receive(:perform)
      expect { service.perform_upload(**args) }.to raise_error JSON::ParserError
    end

    it 'errors on missing File' do
      expect(service).not_to receive(:perform)
      expect { service.perform_upload(**args) }.to raise_error Errno::ENOENT
    end
  end

  describe '#request_upload' do
    it 'instantiates and returns location and uuid' do
      allow(service).to receive(:perform).and_return(upload)

      expect(service).to receive(:perform).with(:post, 'uploads', {}, {})

      location, uuid = service.request_upload

      expect(location).to eq('upload-url-location')
      expect(uuid).to eq('uuid-for-the-upload')
      expect(service.location).to eq(location)
      expect(service.uuid).to eq(uuid)
    end

    context 'existing instance variables' do
      before do
        service.instance_variable_set(:@uploads, true)
        service.instance_variable_set(:@location, 'location')
        service.instance_variable_set(:@uuid, 'uuid')
      end

      it 'returns existing instance values' do
        expect(service).not_to receive(:perform)

        location, uuid = service.request_upload

        expect(location).to eq('location')
        expect(uuid).to eq('uuid')
      end

      it 're-instantiates and return location and uuid' do
        allow(service).to receive(:perform).and_return(upload)

        expect(service).to receive(:perform).with(:post, 'uploads', {}, {})

        location, uuid = service.request_upload(refresh: true)

        expect(location).to eq('upload-url-location')
        expect(uuid).to eq('uuid-for-the-upload')
        expect(service.location).to eq(location)
        expect(service.uuid).to eq(uuid)
      end
    end
  end

  describe '#get_status' do
    it 'gets an upload status' do
      uuid = '12345TEST'
      headers = { 'Accept' => mime_json }

      expect(service).to receive(:perform).with(:get, "uploads/#{uuid}", {}, headers)
      service.get_status(uuid:)
    end
  end

  describe '#bulk_status' do
    it 'requests a status report' do
      uuids = ['12345TEST', '6789FOO', 'BAR!']
      headers = { 'Content-Type' => mime_json, 'Accept' => mime_json }
      data = { ids: uuids }.to_json

      expect(service).to receive(:perform).with(:post, 'uploads/report', data, headers)

      service.bulk_status(uuids:)
    end
  end

  describe '#download' do
    it 'gets the download' do
      uuid = '12345TEST'
      headers = { 'Accept' => Mime[:zip].to_s }

      expect(service).to receive(:perform).with(:get, "uploads/#{uuid}/download", {}, headers)
      service.download(uuid:)
    end
  end

  describe '#valid_metadata?' do
    it 'returns valid metadata' do
      data = service.valid_metadata?(metadata:)
      expect(data).to eq(metadata)
    end

    context 'invalid metadata' do
      it 'errors on missing field' do
        expect do
          service.valid_metadata?(metadata: {})
        end.to raise_error(ArgumentError, 'veteran first name is missing')
      end

      it 'errors on non-string field' do
        expect do
          service.valid_metadata?(metadata: { 'veteranFirstName' => 42 })
        end.to raise_error(ArgumentError, 'veteran first name is not a string')
      end

      it 'errors on blank field' do
        expect do
          service.valid_metadata?(metadata: { 'veteranFirstName' => '' })
        end.to raise_error(ArgumentError, 'veteran first name is blank')

        expect do
          service.valid_metadata?(metadata: { 'veteranFirstName' => '       ' })
        end.to raise_error(ArgumentError, 'veteran first name is blank')

        expect do
          service.valid_metadata?(metadata: { 'veteranFirstName' => '23&_$!42' })
        end.to raise_error(ArgumentError, 'veteran first name is blank')
      end
    end
  end

  describe '#valid_document?' do
    let(:document) { 'fake-file-path' }
    let(:validator) { PDFUtilities::PDFValidator::Validator }
    let(:mock_valid) { OpenStruct.new({ validate: OpenStruct.new({ valid_pdf?: true }) }) }
    let(:mock_invalid) { OpenStruct.new({ validate: OpenStruct.new({ valid_pdf?: false, errors: ['TEST'] }) }) }

    context 'a valid file' do
      before do
        allow(File).to receive(:read).and_return('test-file-read')
        allow(validator).to receive(:new).and_return mock_valid
        allow(service).to receive(:perform).and_return OpenStruct.new({ success?: true })
      end

      it 'returns document path' do
        expect(File).to receive(:read).once.with(document, mode: 'rb')
        expect(service).to receive(:perform).once.with(:post, 'uploads/validate_document', 'test-file-read', anything)

        expect(service.valid_document?(document:)).to eq(document)
      end
    end

    context 'an invalid file' do
      it 'errors reading a missing file' do
        expect do
          service.valid_document?(document:)
        end.to raise_error SystemCallError, /#{document}/
      end

      it 'errors if not a valid PDF' do
        allow(validator).to receive(:new).and_return mock_invalid

        expect do
          service.valid_document?(document:)
        end.to raise_error BenefitsIntake::Service::InvalidDocumentError, 'Invalid Document: ["TEST"]'
      end

      it 'errors on unsuccessful api validation' do
        allow(validator).to receive(:new).and_return mock_valid
        allow(File).to receive(:read).and_return('test-file-read')
        allow(service).to receive(:perform).and_return OpenStruct.new({ success?: false })

        expect do
          service.valid_document?(document:)
        end.to raise_error BenefitsIntake::Service::InvalidDocumentError, /Invalid Document/
      end
    end
  end

  describe '#valid_upload?' do
    it 'returns valid upload parameters when only claim' do
      allow(service).to receive(:valid_document?).and_return('valid-doc-path')

      # no attachments included
      expected = { metadata:, document: 'valid-doc-path', attachments: [] }
      expect(service).to receive(:valid_document?).once

      allow(File).to receive(:size).and_return(1)
      expect(File).to receive(:size).twice

      expect(Common::FileHelpers).to receive(:delete_file_if_exists).once

      response = service.valid_upload?(metadata:, document: 'file-path')
      expect(response).to eq(expected)
    end

    it 'returns valid upload parameters with attachments' do
      allow(service).to receive(:valid_document?).and_return('valid-doc-path')

      expected = {
        metadata:,
        document: 'valid-doc-path',
        attachments: %w[valid-doc-path valid-doc-path]
      }
      expect(service).to receive(:valid_document?).exactly(3).times

      allow(File).to receive(:size).and_return(1)
      expect(File).to receive(:size).exactly(4).times

      expect(Common::FileHelpers).to receive(:delete_file_if_exists).once

      response = service.valid_upload?(metadata:, document: 'file-path', attachments: %w[1 2])
      expect(response).to eq(expected)
    end

    it 'errors on bad metadata' do
      expect do
        service.valid_upload?(metadata: {}, document: 'file-path')
      end.to raise_error ArgumentError
    end

    it 'errors on bad file' do
      expect do
        service.valid_upload?(metadata:, document: 'file-path')
      end.to raise_error SystemCallError
    end

    it 'errors if total file size exceeds limit' do
      allow(service).to receive(:valid_document?).and_return('valid-doc-path')
      allow(File).to receive(:size).and_return(10.gigabytes)

      expect do
        expect(Common::FileHelpers).to receive(:delete_file_if_exists).once
        service.valid_upload?(metadata:, document: 'file-path')
      end.to raise_error BenefitsIntake::Service::UploadSizeExceeded
    end
  end

  # end RSpec.describe
end
