# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Service do
  let(:build_valid_claim_data) { -> { VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json } }
  let(:get_schema) { -> { VetsJsonSchema::SCHEMAS['10-10CG'].clone } }

  it 'will raise a ValidationErrors when the provided claim is invalid' do
    user = nil
    invalid_claim_data = { form: {} }

    expect(CARMA::Models::Submission).not_to receive(:new)

    expect do
      subject.submit_claim!(user, invalid_claim_data)
    end.to raise_error(Common::Exceptions::ValidationErrors)
  end

  it 'will return a Form1010cg::submission' do
    user = nil
    claim_data = { form: build_valid_claim_data.call }
    expected = { carma_case_id: 'aB935000000A9GoCAK', submitted_at: DateTime.new }

    carma_submission = double

    expect(CARMA::Models::Submission).to receive(:from_claim).and_return(carma_submission)
    expect(carma_submission).to receive(:submit!) {
      expect(carma_submission).to receive(:carma_case_id).and_return(expected[:carma_case_id])
      expect(carma_submission).to receive(:submitted_at).and_return(expected[:submitted_at])
    }

    submission = subject.submit_claim!(user, claim_data)

    expect(submission).to be_an_instance_of(Form1010cg::Submission)
    expect(submission.id).to eq(nil)
    expect(submission.carma_case_id).to eq(expected[:carma_case_id])
    expect(submission.submitted_at).to eq(expected[:submitted_at])
    expect(submission.persisted?).to eq(false) # Not persisting until production relsease
  end

  context 'with user context' do
    it 'will delete the related in progress form' do
      user = double(uuid: SecureRandom.uuid)
      claim_data = { form: build_valid_claim_data.call }
      expected = { carma_case_id: 'aB935000000A9GoCAK', submitted_at: DateTime.new }

      # Related in progress form (should be destroyed)
      previously_saved_form = build(
        :in_progress_form,
        form_id: '10-10CG',
        form_data: { name: 'kevin' },
        user_uuid: user.uuid
      )

      expect(InProgressForm).to receive(:form_for_user).and_return(previously_saved_form)
      expect(previously_saved_form).to receive(:destroy)

      # Unrelated in progress forms (should not be destroyed)
      other_form_for_user = create(
        :in_progress_form,
        form_id: '22-1990',
        form_data: { name: 'kevin' },
        user_uuid: user.uuid
      )

      same_form_for_different_user = create(
        :in_progress_form,
        form_id: '10-10CG',
        form_data: { name: 'not-kevin' },
        user_uuid: SecureRandom.uuid
      )

      expect(other_form_for_user).not_to receive(:destroy)
      expect(same_form_for_different_user).not_to receive(:destroy)

      carma_submission = double

      expect(CARMA::Models::Submission).to receive(:from_claim).and_return(carma_submission)
      expect(carma_submission).to receive(:submit!) {
        expect(carma_submission).to receive(:carma_case_id).and_return(expected[:carma_case_id])
        expect(carma_submission).to receive(:submitted_at).and_return(expected[:submitted_at])
      }

      submission = subject.submit_claim!(user, claim_data)

      expect(submission).to be_an_instance_of(Form1010cg::Submission)
      expect(submission.id).to eq(nil)
      expect(submission.carma_case_id).to eq(expected[:carma_case_id])
      expect(submission.submitted_at).to eq(expected[:submitted_at])
      expect(submission.persisted?).to eq(false) # Not persisting until production relsease
    end

    it 'will function when no related in progress form exists' do
      user = double(uuid: SecureRandom.uuid)
      claim_data = { form: build_valid_claim_data.call }
      expected = { carma_case_id: 'aB935000000A9GoCAK', submitted_at: DateTime.new }

      expect_any_instance_of(InProgressForm).not_to receive(:destroy)

      carma_submission = double

      expect(CARMA::Models::Submission).to receive(:from_claim).and_return(carma_submission)
      expect(carma_submission).to receive(:submit!) {
        expect(carma_submission).to receive(:carma_case_id).and_return(expected[:carma_case_id])
        expect(carma_submission).to receive(:submitted_at).and_return(expected[:submitted_at])
      }

      submission = subject.submit_claim!(user, claim_data)

      expect(submission).to be_an_instance_of(Form1010cg::Submission)
      expect(submission.id).to eq(nil)
      expect(submission.carma_case_id).to eq(expected[:carma_case_id])
      expect(submission.submitted_at).to eq(expected[:submitted_at])
      expect(submission.persisted?).to eq(false) # Not persisting until production relsease
    end
  end
end
