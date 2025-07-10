# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/files'
require 'common/file_helpers'

require_relative '../../../support/claims_evidence_api/shared_examples/service'

RSpec.describe ClaimsEvidenceApi::Service::Files do
  let(:service) { described_class.new }
  let(:folder_identifier) { 'VETERAN:FILENUMBER:123456789' }
  let(:headers) { { 'X-Folder-URI' => folder_identifier } }

  let(:uuid) { SecureRandom.hex }
  let(:file_path) { Common::FileHelpers.generate_random_file('TEST FILE') }
  let(:provider_data) { anything } # TODO: use actual field data w/ validation; future pr

  let(:post_params) do
    {
      payload: {
        contentName: File.basename(file_path),
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
      expect(service).to receive(:perform).with(:post, 'files', post_params, headers)
      service.upload(file_path, provider_data:)

      expect(service).to receive(:perform).with(:post, 'files', post_params, headers)
      service.create(file_path, provider_data:)
    end
  end

  describe '#retrieve|read' do
    it 'performs a GET for a specific file' do
      path = "files/#{uuid}/data?includeRawTextData=false"
      expect(service).to receive(:perform).with(:get, path, {}, {})
      service.retrieve(uuid)
    end

    it 'performs a GET for a specific file with raw text included' do
      path = "files/#{uuid}/data?includeRawTextData=true"
      expect(service).to receive(:perform).with(:get, path, {}, {})
      service.read(uuid, include_raw_text: true)
    end
  end

  describe '#update' do
    it 'performs a PUT to a specific file' do
      expect(service).to receive(:perform).with(:put, "files/#{uuid}/data", provider_data, {})
      service.update(uuid, provider_data:)
    end
  end

  describe '#overwrite' do
    it 'performs a POST to a specific file' do
      expect(service).to receive(:perform).with(:post, "files/#{uuid}", post_params, headers)
      service.overwrite(uuid, file_path, provider_data:)
    end
  end
end
