# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/validation/schema'

RSpec.describe ClaimsEvidenceApi::Validation::Schema do
  let(:content_source) { 'VA.gov' }

  describe '#validate_schema_property' do
    it 'returns a valid contentName value' do
      valid = 'test.pdf'
      expect(valid).to eq subject.validate_schema_property(:contentName, valid)
    end

    it 'raises a JSON::Schema::ValidationError' do
      expect { subject.validate_schema_property(:contentName, 'no-extension') }.to raise_error JSON::Schema::ValidationError
    end
  end

  describe '#validate_upload_payload' do
    it 'returns a valid upload payload hash' do
      expected = { contentName: 'foo.bar',
                   providerData: { contentSource: content_source, dateVaReceivedDocument: '1955-11-05',
                                   documentTypeId: 23 } }
      result = subject.validate_upload_payload('foo.bar',
                                               { contentSource: content_source, dateVaReceivedDocument: '1955-11-05',
                                                 documentTypeId: 23 })

      expect(result).to eq expected
    end

    context 'with bad data' do
      it 'checks contentName is a filename with extension' do
        provider_data = { contentSource: content_source, dateVaReceivedDocument: '1955-11-05', documentTypeId: 23 }
        expect { subject.validate_upload_payload('invalid', provider_data) }.to raise_error JSON::Schema::ValidationError
      end

      it 'checks required fields' do
        missing_required = { contentSource: content_source }
        expect { subject.validate_upload_payload('foo.bar', missing_required) }.to raise_error JSON::Schema::ValidationError
      end

      it 'checks field data types' do
        # documentTypeId must be an integer
        invalid_doctypeid = { contentSource: content_source, dateVaReceivedDocument: '1955-11-05',
                              documentTypeId: '23' }
        expect { subject.validate_upload_payload('foo.bar', invalid_doctypeid) }.to raise_error JSON::Schema::ValidationError
      end

      it 'checks field formats' do
        # dateVaReceivedDocument must be YYYY-MM-DD
        invalid_dateformat = { contentSource: content_source, dateVaReceivedDocument: '11-05-1955', documentTypeId: 23 }
        expect { subject.validate_upload_payload('foo.bar', invalid_dateformat) }.to raise_error JSON::Schema::ValidationError
      end
    end
  end

  describe '#validate_provider_data' do
    it 'returns a valid provider data hash' do
      valid = { contentSource: content_source, dateVaReceivedDocument: '1955-11-05', documentTypeId: 23 }
      expect(valid).to eq subject.validate_provider_data(valid)
    end

    it 'raises a JSON::Schema::ValidationError' do
      invalid_doctypeid = { documentTypeId: '23' }
      expect { subject.validate_provider_data(invalid_doctypeid) }.to raise_error JSON::Schema::ValidationError
    end
  end

  describe '#validate_search_file_request' do
    it 'returns a valid file search request hash' do
      valid = { results_per_page: 100, page: 23, filters: nil, sort: nil }
      expected = {
        pageRequest: {
          resultsPerPage: 100,
          page: 23
        },
        filters: {},
        sort: []
      }
      expect(expected).to eq subject.validate_search_file_request(**valid)
    end

    it 'raises a JSON::Schema::ValidationError' do
      invalid = { results_per_page: 10, page: -1, filters: nil, sort: nil }
      expect { subject.validate_search_file_request(**invalid) }.to raise_error JSON::Schema::ValidationError
    end
  end
end
