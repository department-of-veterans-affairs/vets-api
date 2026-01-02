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
end
