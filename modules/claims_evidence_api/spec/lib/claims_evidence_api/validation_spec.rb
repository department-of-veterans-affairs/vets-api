# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/validation'

RSpec.describe ClaimsEvidenceApi::Validation do
  let(:content_source) { 'VA.gov' }

  describe '#validate_folder_identifier' do
    it 'returns the valid identifier' do
      valid = 'VETERAN:SSN:123456789'
      expect(valid).to eq subject.validate_folder_identifier(valid)
    end

    it 'raises an InvalidFolderType' do
      expect { subject.validate_folder_identifier('invalid') }.to raise_error ClaimsEvidenceApi::FolderIdentifier::InvalidFolderType
    end

    it 'raises an InvalidIdentifierType' do
      expect { subject.validate_folder_identifier('VETERAN:invalid:ID') }.to raise_error ClaimsEvidenceApi::FolderIdentifier::InvalidIdentifierType
    end
  end

  describe '#validate_field_value' do
    it 'returns the valid value' do
      valid = 'a string'
      expect(valid).to eq subject.validate_field_value(valid, field_type: :string)
    end

    it 'raises an ArgumentError' do
      expect { subject.validate_field_value('invalid', field_type: :invalid) }.to raise_error ArgumentError
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

  describe '#validate_schema_property' do
    it 'returns a valid contentName value' do
      valid = 'test.pdf'
      expect(valid).to eq subject.validate_schema_property(:contentName, valid)
    end

    it 'raises a JSON::Schema::ValidationError' do
      expect { subject.validate_schema_property(:contentName, 'no-extension') }.to raise_error JSON::Schema::ValidationError
    end
  end
end
