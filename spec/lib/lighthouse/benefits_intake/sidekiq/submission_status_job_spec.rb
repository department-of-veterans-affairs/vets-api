# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

Rspec.describe BenefitsIntake::SubmissionStatusJob, type: :job do
  let(:job) { described_class.new }

  context 'flipper is disabled' do
    before do
      Flipper.disable(:benefits_intake_submission_status_job)
    end

    it 'does nothing' do
      expect(Rails.logger).not_to receive(:info)  # does not log start
      expect(Rails.logger).not_to receive(:error) # does not log error
      expect(FormSubmissionAttempt).not_to receive(:where)
      expect(BenefitsIntake::Service).not_to receive(:new)
      job.perform
    end
  end

  context 'flipper is enabled' do
    before do
      Flipper.enable(:benefits_intake_submission_status_job)
    end
  end

end
