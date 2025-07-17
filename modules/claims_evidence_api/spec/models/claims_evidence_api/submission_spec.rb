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
end
