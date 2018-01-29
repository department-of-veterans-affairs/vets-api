# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::VICSubmission, type: :model do
  describe '#update_state_to_completed' do
    it 'should set the state when then response is set' do
      submission = described_class.new
      submission.response = { foo: true}
      expect(submission.valid?).to eq(true)
      expect(submission.state).to eq('success')
    end
  end

  describe '#create_submission_job' do
    it 'should create a submission job after create' do
      vic_submission = build(:vic_submission)
      allow_any_instance_of(described_class).to receive(:id).and_return(1)
      expect(VIC::SubmissionJob).to receive(:perform_async).with(1, vic_submission.form)
      vic_submission.save!
    end
  end
end
