# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/x_folder_uri'

RSpec.describe ClaimsEvidenceApi::XFolderUri do
  subject { ClaimsEvidenceApi::XFolderUri }

  describe '#generate' do
    it 'creates a valid folder identifier' do
      args = ['VETERAN', 'FILENUMBER', '987267855']
      x_folder_uri = subject.generate(*args)
      expect(x_folder_uri).to eq args.join(':')
    end

    it 'transforms valid arguments' do
      args = ['veteran', 'FileNumber', 987267855]
      x_folder_uri = subject.generate(*args)
      expect(x_folder_uri).to eq "#{args[0]}:#{args[1]}:#{args[2]}".upcase
    end

    it 'handles a SEARCH identifier_type' do
      args = ['VETERAN', 'SEARCH', 'foo=bar&ssn=test']
      x_folder_uri = subject.generate(*args)
      expect(x_folder_uri).to eq args.join(':')
    end
  end

  describe '#validate' do
    it 'handles a valid folder identifier' do
      fid = 'VETERAN:FILENUMBER:987267855'
      x_folder_uri = subject.validate(fid)
      expect(fid).to eq x_folder_uri
    end

    it 'transforms valid arguments' do
      fid = 'veteran:FileNumber:987267855'
      x_folder_uri = subject.validate(fid)
      expect(fid.upcase).to eq x_folder_uri
    end
  end

  context 'with invalid arguments' do
    it 'errors on invalid folder_type' do
      expect(subject).not_to receive(:validate_identifier_type)

      args = ['INVALID', 'FILENUMBER', '987267855']
      expect { subject.generate(*args) }.to raise_error ArgumentError
    end

    it 'errors on invalid identifier_type' do
      expect(subject).not_to receive(:validate_id)

      args = ['VETERAN', 'INVALID', '987267855']
      expect { subject.generate(*args) }.to raise_error ArgumentError
    end

    it 'errors on invalid folder_type and identifier_type combination' do
      expect(subject).not_to receive(:validate_id)

      args = ['PERSON', 'SSN', '987267855']
      expect { subject.generate(*args) }.to raise_error ArgumentError
    end
  end
end
