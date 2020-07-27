# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Service do
  let(:build_valid_claim_data) { -> { VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json } }
  let(:get_schema) { -> { VetsJsonSchema::SCHEMAS['10-10CG'].clone } }

  it 'will raise a ValidationErrors when the provided claim is invalid' do
    invalid_claim_data = { form: {} }

    expect(CARMA::Models::Submission).not_to receive(:new)

    expect do
      subject.submit_claim!(invalid_claim_data)
    end.to raise_error(Common::Exceptions::ValidationErrors)
  end

  it 'will return a Form1010cg::submission' do
    claim_data = { form: build_valid_claim_data.call }
    expected = { carma_case_id: 'aB935000000A9GoCAK', submitted_at: DateTime.new }

    carma_submission = double

    expect(CARMA::Models::Submission).to receive(:from_claim).and_return(carma_submission)
    expect(carma_submission).to receive(:submit!) {
      expect(carma_submission).to receive(:carma_case_id).and_return(expected[:carma_case_id])
      expect(carma_submission).to receive(:submitted_at).and_return(expected[:submitted_at])
    }

    submission = subject.submit_claim!(claim_data)

    expect(submission).to be_an_instance_of(Form1010cg::Submission)
    expect(submission.carma_case_id).to eq(expected[:carma_case_id])
    expect(submission.submitted_at).to eq(expected[:submitted_at])
  end
end
