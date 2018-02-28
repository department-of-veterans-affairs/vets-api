# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::VICSubmission, type: :model do
  let(:vic_submission) { build(:vic_submission) }

  describe '#update_state_to_completed' do
    it 'should set the state when then response is set' do
      submission = described_class.new
      submission.save(validate: false)
      submission.response = { foo: true }
      expect(submission.valid?).to eq(true)
      expect(submission.state).to eq('success')
    end
  end

  describe '#no_forbidden_fields' do
    context 'with no forbidden fields' do
      it 'should be valid' do
        expect(build(:vic_submission_loa3_user).valid?).to eq(true)
      end
    end

    context 'with forbidden fields' do
      it 'should be invalid' do
        vic_submission.user = build(:user, :loa3)
        error = 'veteranDateOfBirth, veteranFullName, and veteranSocialSecurityNumber fields not allowed for loa3 user'
        expect_attr_invalid(vic_submission, :form, error)
      end
    end
  end

  describe '#create_submission_job' do
    it 'should create a submission job after create' do
      allow_any_instance_of(described_class).to receive(:id).and_return(1)
      expect(VIC::SubmissionJob).to receive(:perform_async).with(1, vic_submission.form, nil)
      vic_submission.save!
    end
  end

  describe '#form_matches_schema' do
    context 'with an invalid form' do
      it 'should have a schema error' do
        submission = described_class.new(form: { foo: 1 }.to_json)
        expect(submission.valid?).to eq(false)
        expect(
          submission.errors[:form][0].include?(
            "The property '#/' contains additional properties [\"foo\"]"
          )
        ).to eq(true)
      end
    end
  end
end
