# frozen_string_literal: true

require 'rails_helper'

require 'support/models/shared_examples/submission'

RSpec.describe ClaimsEvidenceApi::Submission, type: :model do
  let(:submission) { described_class.new }

  it_behaves_like 'a Submission model'

  context 'sets and retrieves x_folder_uri' do
    before do
      submission.reference_data = nil
    end

    it 'accepts separate arguments' do
      expect(submission.reference_data).to be_nil

      args = %w[VETERAN FILENUMBER 987267855]
      x_folder_uri = submission.x_folder_uri_set(*args)
      expect(x_folder_uri).to eq submission.x_folder_uri
      expect(x_folder_uri).to eq args.join(':')
    end

    it 'directly assigns the value' do
      expect(submission.reference_data).to be_nil

      fid = 'VETERAN:FILENUMBER:987267855'
      submission.x_folder_uri = fid
      expect(fid).to eq submission.x_folder_uri
    end
  end

  context 'populates reference_data' do
    before do
      submission.reference_data = nil
    end

    it 'accepts unnammed and named values' do
      expect(submission.reference_data).to be_nil

      expected = {'data' => [42], 'foo' => 'bar'}
      submission.update_reference_data(42, foo: 'bar')
      expect(submission.reference_data).to eq expected
    end

    it 'set x_folder_uri if included in named values' do
      expect(submission.reference_data).to be_nil
      expect(submission).to receive(:x_folder_uri=).and_call_original

      expected_uri = 'VETERAN:SSN:123456789'
      expected_data = {'data' => [42], 'foo' => 'bar', 'x_folder_uri' => expected_uri}
      submission.update_reference_data(42, foo: 'bar', x_folder_uri: expected_uri)
      expect(submission.reference_data).to eq expected_data
      expect(submission.x_folder_uri).to eq expected_uri
    end
  end

  context 'with invalid x_folder_uri' do
    let(:invalid_fid) { 'VETERAN:INVALID:123' }

    it 'x_folder_uri= raises an error' do
      expect { submission.x_folder_uri = invalid_fid }.to raise_error ClaimsEvidenceApi::XFolderUri::InvalidIdentifierType
    end

    it 'update_reference_data raises an error' do
      expect { submission.update_reference_data(x_folder_uri: invalid_fid)}.to raise_error ClaimsEvidenceApi::XFolderUri::InvalidIdentifierType
    end
  end
end
