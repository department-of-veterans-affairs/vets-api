# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitsIntakeStatusPollJob, type: :job do
  describe '#perform' do
    describe 'submission to the bulk status report endpoint'
      it 'submits pending form submissions' do
        # TODO: Create a :pending trait
        pending_form_submission_ids = create_list(:form_submission, 2, :pending).map(&:benefits_intake_uuid)
        allow_any_instance_of(BenefitsIntakeService::Service).to receive(:get_bulk_status_of_uploads)
          .with(pending_form_submission_ids)

        BenefitsIntakeStatusPollJob.new.perform

        expect_any_instance_of(BenefitsIntakeService::Service).to have_recieved(:get_bulk_status_of_uploads)
          .with(pending_form_submission_ids)
      end

      it 'does not submit successful form submissions' do
        # TODO: Create a :success trait
        successful_form_submission_ids = create_list(:form_submission, 2, :success).map(&:benefits_intake_uuid)
        allow_any_instance_of(BenefitsIntakeService::Service).to receive(:get_bulk_status_of_uploads)

        BenefitsIntakeStatusPollJob.new.perform

        expect_any_instance_of(BenefitsIntakeService::Service).not.to have_recieved(:get_bulk_status_of_uploads)
      end

      it 'does not submit errored form submissions' do
        # TODO: Create an :error trait
        errored_form_submission_ids = create_list(:form_submission, 2, :error).map(&:benefits_intake_uuid)
        allow_any_instance_of(BenefitsIntakeService::Service).to receive(:get_bulk_status_of_uploads)

        BenefitsIntakeStatusPollJob.new.perform

        expect_any_instance_of(BenefitsIntakeService::Service).not.to have_recieved(:get_bulk_status_of_uploads)
      end
    end

    describe 'updating the form submission status'
      it 'updates the status with success from the bulk status report endpoint' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_bulk_status_report_success') do
          # TODO: Create a :pending trait
          pending_form_submissions = create_list(:form_submission, 2, :pending)

          BenefitsIntakeStatusPollJob.new.perform

          pending_form_submissions.reload.each do |form_submission|
            expect(form_submission.status).to eq :success
          end
        end
      end

      it 'updates the status with error from the bulk status report endpoint' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_bulk_status_report_error') do
          # TODO: Create a :pending trait
          pending_form_submissions = create_list(:form_submission, 2, :pending)

          BenefitsIntakeStatusPollJob.new.perform

          pending_form_submissions.reload.each do |form_submission|
            expect(form_submission.status).to eq :error
          end
        end
      end
    end
  end
end
