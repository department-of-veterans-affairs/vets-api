# frozen_string_literal: true

require 'rails_helper'

require 'support/models/shared_examples/submission'

RSpec.describe ClaimsEvidenceApi::Submission, type: :model do
  let(:submission) { described_class.new }

  it_behaves_like 'a Submission model'

  context 'sets and retrieves folder_identifier/folder_identifier' do
    before do
      submission.reference_data = nil
    end

    it 'accepts separate arguments' do
      expect(submission.reference_data).to be_nil

      args = %w[VETERAN FILENUMBER 987267855]
      folder_identifier = submission.folder_identifier_set(*args)
      expect(folder_identifier).to eq submission.folder_identifier
      expect(folder_identifier).to eq args.join(':')
    end

    it 'directly assigns the value' do
      expect(submission.reference_data).to be_nil

      fid = 'VETERAN:FILENUMBER:987267855'
      submission.folder_identifier = fid
      expect(fid).to eq submission.folder_identifier
    end
  end

  context 'populates reference_data' do
    before do
      submission.reference_data = nil
    end

    it 'accepts unnamed and named values' do
      expect(submission.reference_data).to be_nil

      expected = { __: ['TEST', 42], foo: 'bar' }
      submission.update_reference_data('TEST', 42, foo: 'bar')
      expect(submission.reference_data).to eq expected.deep_stringify_keys
    end

    it 'set folder_identifier if included in named values' do
      expect(submission.reference_data).to be_nil
      expect(submission).to receive(:folder_identifier=).and_call_original

      expected_uri = 'VETERAN:SSN:123456789'
      expected_data = { __: ['TEST', 42], foo: 'bar', folder_identifier: [expected_uri],
                        latest_folder_identifier: expected_uri }
      submission.update_reference_data('TEST', 42, foo: 'bar', folder_identifier: expected_uri)
      expect(submission.reference_data).to eq expected_data.deep_stringify_keys
      expect(submission.folder_identifier).to eq expected_uri
    end
  end

  context 'with invalid folder_identifier' do
    let(:invalid_fid) { 'VETERAN:INVALID:123' }

    it 'folder_identifier= raises an error' do
      expect { submission.folder_identifier = invalid_fid }.to raise_error ClaimsEvidenceApi::FolderIdentifier::InvalidIdentifierType
    end

    it 'update_reference_data raises an error' do
      expect { submission.update_reference_data(folder_identifier: invalid_fid) }.to raise_error ClaimsEvidenceApi::FolderIdentifier::InvalidIdentifierType
    end
  end
end
