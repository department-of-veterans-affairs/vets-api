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
    claim_data        = { form: build_valid_claim_data.call }
    carma_submission  = double
    mvi_lookup_1      = double(status: 'OK', profile: double(icn: 'ICN_1'))
    mvi_lookup_2      = double(status: 'OK', profile: double(icn: 'ICN_2'))
    mvi_lookup_3      = double(status: 'OK', profile: double(icn: 'ICN_3'))

    expected = {
      metadata_argument: {
        veteran: {
          icn: mvi_lookup_1.profile.icn
        },
        primaryCaregiver: {
          icn: mvi_lookup_2.profile.icn
        },
        secondaryCaregiverOne: {
          icn: mvi_lookup_3.profile.icn
        }
      },
      results: {
        carma_case_id: 'aB935000000A9GoCAK',
        submitted_at: DateTime.new
      }
    }

    expect(CARMA::Models::Submission).to receive(:from_claim).and_return(carma_submission)
    expect(carma_submission).to receive(:metadata=).with(expected[:metadata_argument])
    expect(carma_submission).to receive(:submit!) {
      expect(carma_submission).to receive(:carma_case_id).and_return(expected[:results][:carma_case_id])
      expect(carma_submission).to receive(:submitted_at).and_return(expected[:results][:submitted_at])
    }

    expect_any_instance_of(
      MVI::Service
    ).to receive(
      :find_profile
    ).and_return(mvi_lookup_1, mvi_lookup_2, mvi_lookup_3)

    submission = subject.submit_claim!(claim_data)

    expect(submission).to be_an_instance_of(Form1010cg::Submission)
    expect(submission.carma_case_id).to eq(expected[:results][:carma_case_id])
    expect(submission.submitted_at).to eq(expected[:results][:submitted_at])
  end
end
