# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/validation'

RSpec.describe ClaimsEvidenceApi::Validation do
  describe '#validate_folder_identifier' do
    it 'returns the valid identifier' do
      valid = 'VETERAN:SSN:123456789'
      expect(valid).to eq subject.validate_folder_identifier(valid)
    end

    it 'raises an ArgumentError' do
      expect { subject.validate_folder_identifier('invalid') }.to raise_error ArgumentError
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
      expected = {:contentName=>"foo.bar", :providerData=>{:contentSource=>"va.gov", :dateVaReceivedDocument=>'1955-11-05', :documentTypeId=>23}}
      result = subject.validate_upload_payload('foo.bar', {contentSource: 'va.gov', dateVaReceivedDocument: '1955-11-05', documentTypeId: 23})

      expect(result).to eq expected
    end

    context 'with bad data' do
      it 'checks required fields' do
        missingRequired = {contentSource: 'va.gov'}
        expect { subject.validate_upload_payload('foo.bar', missingRequired) }.to raise_error JSON::Schema::ValidationError
      end

      it 'checks field data types' do
        # documentTypeId must be an integer
        invalidDocTypeId = {contentSource: 'va.gov', dateVaReceivedDocument: '1955-11-05', documentTypeId: '23'}
        expect { subject.validate_upload_payload('foo.bar', invalidDocTypeId) }.to raise_error JSON::Schema::ValidationError
      end

      it 'checks field formats' do
        # dateVaReceivedDocument must be YYYY-MM-DD
        invalidDateFormat = {contentSource: 'va.gov', dateVaReceivedDocument: '11-05-1955', documentTypeId: 23}
        expect { subject.validate_upload_payload('foo.bar', invalidDateFormat) }.to raise_error JSON::Schema::ValidationError
      end
    end
  end

  describe '#validate_provider_data' do
    it 'returns a valid provider data hash' do
      valid = {:contentSource=>"va.gov", :dateVaReceivedDocument=>'1955-11-05', :documentTypeId=>23}
      expect(valid).to eq subject.validate_provider_data(valid)
    end

    it 'raises a JSON::Schema::ValidationError' do
      invalidDocTypeId = {documentTypeId: '23'}
      expect { subject.validate_provider_data(invalidDocTypeId) }.to raise_error JSON::Schema::ValidationError
    end
  end
end
