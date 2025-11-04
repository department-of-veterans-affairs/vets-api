# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/search'

require_relative 'shared/service'

RSpec.describe ClaimsEvidenceApi::Service::Search do
  let(:service) { described_class.new }
  let(:folder_identifier) { 'VETERAN:FILENUMBER:123456789' }
  let(:headers) { { 'X-Folder-URI' => folder_identifier } }

  let(:search_filters) { ClaimsEvidenceApi::Validation::SearchFileRequest::Filters }
  let(:search_sort) { ClaimsEvidenceApi::Validation::SearchFileRequest::Sort }

  before do
    service.folder_identifier = folder_identifier
  end

  it_behaves_like 'a ClaimsEvidenceApi::Service class'

  describe '#find' do
    it 'performs a POST to folders/files:search using defaults' do
      defaults = { results_per_page: 10, page: 1, filters: {}, sort: [] }
      request = {
        pageRequest: {
          resultsPerPage: 10,
          page: 1
        },
        filters: {},
        sort: []
      }

      expect(service).to receive(:validate_folder_identifier).and_call_original
      expect(search_filters).to receive(:transform).with({}).and_call_original
      expect(search_sort).to receive(:transform).with({}).and_call_original
      expect(service).to receive(:validate_search_file_request).with(**defaults).and_call_original
      expect(service).to receive(:perform).with(:post, 'folders/files:search', request, headers)
      service.find # use all default params
    end

    it 'performs a POST to folders/files:search using supplied params' do
      args = {
        results_per_page: 142,
        page: 23,
        filters: { documentTypeId: [450] },
        sort: { documentTypeId: 'ascending' }
      }

      filters = {
        'providerData.documentTypeId' => {
          evaluationType: 'EQUALS',
          value: [450].to_json
        }
      }
      sort = [{
        property: 'providerData.documentTypeId',
        direction: 'ASCENDING'
      }]

      valid = args.deep_dup.merge({ filters:, sort: })

      request = {
        pageRequest: {
          resultsPerPage: 142,
          page: 23
        },
        filters:,
        sort:
      }

      expect(service).to receive(:validate_folder_identifier).and_call_original
      expect(search_filters).to receive(:transform).with(args[:filters]).and_call_original
      expect(search_sort).to receive(:transform).with(args[:sort]).and_call_original
      expect(service).to receive(:validate_search_file_request).with(**valid).and_call_original
      expect(service).to receive(:perform).with(:post, 'folders/files:search', request, headers)
      service.find(**args)
    end

    it 'raises an exception if folder_identifier is not defined' do
      service.instance_variable_set(:@folder_identifier, nil)
      expect { service.find }.to raise_error ClaimsEvidenceApi::Service::Search::UndefinedXFolderURI
    end

    it 'raises an exception if schema is not valid' do
      expect { service.find(results_per_page: 23, page: -1) }.to raise_error JSON::Schema::ValidationError
    end
  end
end
