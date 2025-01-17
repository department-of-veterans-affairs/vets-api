# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

Rspec.describe BenefitsIntake::SubmissionStatusJob, type: :job do
  let(:job) { described_class.new }
  let(:service) { BenefitsIntake::Service.new }
  let(:response) { double(body: { 'data' => [] }, success?: true) }

  context 'flipper is disabled' do
    before do
      Flipper.disable(:benefits_intake_submission_status_job)
    end

    it 'does nothing' do
      expect(Rails.logger).not_to receive(:info)
      expect(Rails.logger).not_to receive(:error)
      expect(FormSubmissionAttempt).not_to receive(:where)
      expect(BenefitsIntake::Service).not_to receive(:new)
      job.perform
    end
  end

  context 'flipper is enabled' do
    before do
      Flipper.enable(:benefits_intake_submission_status_job)

      allow(BenefitsIntake::Service.new).to receive(:new).and_return(service)
    end

    context 'multiple attempts and multiple form submissions' do
      before do
        create_list(:form_submission, 2, :success)
        create_list(:form_submission, 2, :failure)
      end

      let(:pending_fsa_ids) do
        create_list(:form_submission_attempt, 2, :pending).map(&:benefits_intake_uuid)
      end

      it 'submits only pending form submissions' do
        expect(service).to receive(:bulk_status).with(uuids: pending_fsa_ids).and_return(response)

        expect(StatsD).not_to receive(:increment)

        job.perform
      end
    end

  end

end
