# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/validation/search_file_request'

RSpec.describe ClaimsEvidenceApi::Validation::SearchFileRequest do
  let(:search_filters) { ClaimsEvidenceApi::Validation::SearchFileRequest::Filters }
  let(:search_sort) { ClaimsEvidenceApi::Validation::SearchFileRequest::Sort }

  it 'has expected constants' do
    expect(ClaimsEvidenceApi::Validation::SearchFileRequest::FORMATTERS).to be_present
  end

  it 'has formatters in expected structure' do
    # value of the first key-value pair of formatters
    formatter = ClaimsEvidenceApi::Validation::SearchFileRequest::FORMATTERS.first[1]

    expect(File.exist?(formatter.file)).to be true
    expect(formatter.filter).to be_a(Symbol)
    expect(formatter.search_field).to be_a(String)
    expect(formatter.evaluation).to be_a(String)
    expect(formatter.value_type).to be_present
  end

  context 'Filters' do
    it 'returns a valid filter list' do
      empty = {}
      expect(search_filters.validate(empty)).to eq({})

      valid = {
        'providerData.documentTypeId' => {
          evaluationType: 'EQUALS',
          value: [450].to_json
        }
      }
      expect(search_filters.validate(valid)).to eq valid
    end

    it 'raises an exception on an invalid filter list' do
      invalid = {
        'providerData.documentTypeId' => {
          evaluationType: 'EQUALS',
          value: [450] # needs to be a json string
        }
      }
      expect { search_filters.validate(invalid) }.to raise_error JSON::Schema::ValidationError
    end

    it 'transforms a key-value hash to expected schema format' do
      filters = {
        documentTypeId: [450],
        contentSource: 'VA.gov',
        hasAnnotations: true,
        subject: 'something',
        notValidField: 'will be removed'
      }

      expected = {
        'providerData.documentTypeId' => {
          evaluationType: 'EQUALS',
          value: [450].to_json
        },
        'providerData.contentSource' => {
          evaluationType: 'EQUALS',
          value: 'VA.gov'
        },
        'providerData.hasAnnotations' => {
          evaluationType: 'EQUALS',
          value: true
        },
        'providerData.subject' => {
          evaluationType: 'CONTAINS',
          value: 'something'
        }
      }

      expect(search_filters.transform(filters)).to eq expected
    end
  end

  context 'Sort' do
    it 'returns a valid sort list' do
      empty = []
      expect(search_sort.validate(empty)).to eq([])

      valid = [{ 'property' => 'providerData.contentSource', 'direction' => 'ASCENDING' }]
      expect(search_sort.validate(valid)).to eq valid
    end

    it 'raises an exception on an invalid sort list - no required' do
      invalid = { 'missingRequired' => 'TEST' }
      expect { search_sort.validate(invalid) }.to raise_error JSON::Schema::ValidationError
    end

    it 'raises an exception on an invalid sort list - bad direction' do
      invalid = { 'property' => 'providerData.contentSource', 'direction' => 'TEST' }
      expect { search_sort.validate(invalid) }.to raise_error JSON::Schema::ValidationError
    end

    it 'transforms a key-value hash to expected schema format' do
      sort = {
        documentTypeId: 'ASCENDING',
        contentSource: 'DESCENDING',
        notValidField: 'will be removed'
      }

      expected = [
        { property: 'providerData.documentTypeId', direction: 'ASCENDING' },
        { property: 'providerData.contentSource', direction: 'DESCENDING' }
      ]

      expect(search_sort.transform(sort)).to eq expected
    end
  end
end
