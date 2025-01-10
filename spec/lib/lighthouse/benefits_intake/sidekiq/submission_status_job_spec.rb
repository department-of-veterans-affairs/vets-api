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
      expect(Rails.logger).not_to receive(:info).with("BenefitsIntake::SubmissionStatusJob: started")
      job.perform
    end
  end

  context 'flipper is enabled' do
    before do
      Flipper.enable(:benefits_intake_submission_status_job)
    end
  end

end
