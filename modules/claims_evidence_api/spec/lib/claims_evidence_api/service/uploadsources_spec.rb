# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/uploadsources'

require_relative 'shared/service'

RSpec.describe ClaimsEvidenceApi::Service::UploadSources do
  let(:service) { described_class.new }
  let(:folder_identifier) { 'VETERAN:FILENUMBER:123456789' }
  let(:headers) { { 'X-Folder-URI' => folder_identifier } }

  before do
    service.folder_identifier = folder_identifier
  end

  it_behaves_like 'a ClaimsEvidenceApi::Service class'

  describe '#retrieve' do
    it 'performs a GET' do
      path = 'folders/uploadsources'
      expect(service).to receive(:perform).with(:get, path, {}, headers)
      service.retrieve
    end

    it 'raises an exception if folder_identifier is not defined' do
      service.instance_variable_set(:@folder_identifier, nil)
      expect { service.retrieve }.to raise_error ClaimsEvidenceApi::Service::UploadSources::UndefinedXFolderURI
    end
  end
end
