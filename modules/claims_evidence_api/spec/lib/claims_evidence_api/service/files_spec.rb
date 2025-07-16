# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/files'
require 'common/file_helpers'
require 'common/virus_scan'

require_relative '../../../support/claims_evidence_api/shared_examples/service'

RSpec.describe ClaimsEvidenceApi::Service::Files do
  let(:service) { described_class.new }
  let(:folder_identifier) { 'VETERAN:FILENUMBER:123456789' }
  let(:headers) { { 'X-Folder-URI' => folder_identifier } }

  let(:uuid) { SecureRandom.hex }
  let(:file_path) { Common::FileHelpers.generate_random_file('TEST FILE', '.test') }
  let(:file_name) { File.basename(file_path) }
  let(:provider_data) do
    # minimally required fields
    { contentSource: 'va.gov', dateVaReceivedDocument: '1955-11-05', documentTypeId: 23 }
  end

  let(:post_params) do
    {
      payload: {
        contentName: file_name,
        providerData: provider_data
      },
      file: anything
    }
  end

  after do
    Common::FileHelpers.delete_file_if_exists(file_path)
  end

  before do
    service.x_folder_uri = folder_identifier
  end

  it_behaves_like 'a ClaimsEvidenceApi::Service class'

  describe '#upload|create' do
    it 'performs a POST to files' do
      expect(service).to receive(:validate_upload_payload).with(file_name, provider_data).and_call_original
      expect(service).to receive(:perform).with(:post, 'files', post_params, headers)
      service.upload(file_path, provider_data:)

      expect(service).to receive(:validate_upload_payload).with(file_name, provider_data).and_call_original
      expect(service).to receive(:perform).with(:post, 'files', post_params, headers)
      service.create(file_path, provider_data:)
    end

    it 'raises an exception if x_folder_uri is not defined' do
      service.instance_variable_set(:@x_folder_uri, nil)
      expect { service.create(file_path, provider_data:) }.to raise_error ClaimsEvidenceApi::Service::Files::UndefinedXFolderURI
    end

    it 'raises an error on missing file' do
      expect { service.create('BAD_FILE', provider_data:) }.to raise_error ClaimsEvidenceApi::Service::Files::FileNotFound
    end

    it 'raises an error if virus found' do
      allow(Common::VirusScan).to receive(:scan).and_return false
      expect { service.create(file_path, provider_data:) }.to raise_error ClaimsEvidenceApi::Service::Files::VirusFound
    end
  end

  describe '#retrieve|read' do
    it 'performs a GET for a specific file' do
      path = "files/#{uuid}/data?includeRawTextData=false"
      expect(service).to receive(:perform).with(:get, path, {})
      service.retrieve(uuid)
    end

    it 'performs a GET for a specific file with raw text included' do
      path = "files/#{uuid}/data?includeRawTextData=true"
      expect(service).to receive(:perform).with(:get, path, {})
      service.read(uuid, include_raw_text: true)
    end
  end

  describe '#update' do
    it 'performs a PUT to a specific file' do
      expect(service).to receive(:validate_provider_data).with(provider_data).and_call_original
      expect(service).to receive(:perform).with(:put, "files/#{uuid}/data", provider_data)
      service.update(uuid, provider_data:)
    end
  end

  describe '#overwrite' do
    it 'performs a POST to a specific file' do
      expect(service).to receive(:validate_upload_payload).with(file_name, provider_data).and_call_original
      expect(service).to receive(:perform).with(:post, "files/#{uuid}", post_params, headers)
      service.overwrite(uuid, file_path, provider_data:)
    end

    it 'raises an exception if x_folder_uri is not defined' do
      service.instance_variable_set(:@x_folder_uri, nil)
      expect { service.overwrite(uuid, file_path, provider_data:) }.to raise_error ClaimsEvidenceApi::Service::Files::UndefinedXFolderURI
    end

    it 'raises an error on missing file' do
      expect { service.overwrite(uuid, 'BAD_FILE', provider_data:) }.to raise_error ClaimsEvidenceApi::Service::Files::FileNotFound
    end

    it 'raises an error if virus found' do
      allow(Common::VirusScan).to receive(:scan).and_return false
      expect { service.overwrite(uuid, file_path, provider_data:) }.to raise_error ClaimsEvidenceApi::Service::Files::VirusFound
    end
  end
end
