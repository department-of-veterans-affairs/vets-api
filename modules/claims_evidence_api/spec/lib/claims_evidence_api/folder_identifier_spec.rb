# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/folder_identifier'

RSpec.describe ClaimsEvidenceApi::FolderIdentifier do
  subject { ClaimsEvidenceApi::FolderIdentifier }

  describe '#generate' do
    it 'creates a valid folder identifier' do
      args = %w[VETERAN FILENUMBER 987267855]
      folder_identifier = subject.generate(*args)
      expect(folder_identifier).to eq args.join(':')
    end

    it 'transforms valid arguments' do
      args = ['veteran', 'FileNumber', 987_267_855]
      folder_identifier = subject.generate(*args)
      expect(folder_identifier).to eq "#{args[0]}:#{args[1]}:#{args[2]}".upcase
    end

    it 'handles a SEARCH identifier_type' do
      args = ['VETERAN', 'SEARCH', 'foo=bar&ssn=test']
      folder_identifier = subject.generate(*args)
      expect(folder_identifier).to eq args.join(':')
    end
  end

  describe '#validate' do
    it 'handles a valid folder identifier' do
      fid = 'VETERAN:FILENUMBER:987267855'
      folder_identifier = subject.validate(fid)
      expect(fid).to eq folder_identifier
    end

    it 'transforms valid arguments' do
      fid = 'veteran:FileNumber:987267855'
      folder_identifier = subject.validate(fid)
      expect(fid.upcase).to eq folder_identifier
    end
  end

  context 'with invalid arguments' do
    let(:folder_identifier) { ClaimsEvidenceApi::FolderIdentifier }

    it 'errors on invalid folder_type' do
      expect(folder_identifier).not_to receive(:validate_identifier_type)

      args = %w[INVALID FILENUMBER 987267855]
      expect { folder_identifier.generate(*args) }.to raise_error folder_identifier::InvalidFolderType
    end

    it 'errors on invalid identifier_type' do
      expect(folder_identifier).not_to receive(:validate_id)

      args = %w[VETERAN INVALID 987267855]
      expect { folder_identifier.generate(*args) }.to raise_error folder_identifier::InvalidIdentifierType
    end

    it 'errors on invalid folder_type and identifier_type combination' do
      expect(folder_identifier).not_to receive(:validate_id)

      args = %w[PERSON SSN 987267855]
      expect { folder_identifier.generate(*args) }.to raise_error folder_identifier::InvalidIdentifierType
    end
  end
end
