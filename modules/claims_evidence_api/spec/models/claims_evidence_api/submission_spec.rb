# frozen_string_literal: true

require 'rails_helper'
require 'models/_shared_examples/submission'

RSpec.describe ClaimsEvidenceApi::Submission, type: :model do
  let(:submission) { described_class.new }

  it_behaves_like 'a Submission model'

  it 'sets and retrieves x_folder_uri' do
    expect(submission.reference_data).to be_nil

    x_folder_uri = submission.x_folder_uri('just', 'a', 'test')
    expect(x_folder_uri).to eq submission.x_folder_uri?
    expect(x_folder_uri).to eq 'just:a:test'
  end
end
