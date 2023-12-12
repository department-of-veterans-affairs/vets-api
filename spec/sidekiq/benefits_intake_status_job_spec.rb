# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitsIntakeStatusJob, type: :job do
  describe '#perform' do
    describe 'submission to the bulk status report endpoint' do
      it 'submits only pending form submissions' do
        pending_form_submission_ids = create_list(:form_submission, 2, :pending).map(&:benefits_intake_uuid)
        create_list(:form_submission, 2, :success)
        create_list(:form_submission, 2, :error)
        allow_any_instance_of(BenefitsIntakeService::Service).to receive(:get_bulk_status_of_uploads)
          .with(pending_form_submission_ids)

        BenefitsIntakeStatusJob.new.perform

        expect_any_instance_of(BenefitsIntakeService::Service).to have_recieved(:get_bulk_status_of_uploads)
          .with(pending_form_submission_ids)
      end
    end

    describe 'updating the form submission status' do
      it 'updates the status with success from the bulk status report endpoint' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_bulk_status_report_success') do
          pending_form_submissions = create_list(:form_submission, 2, :pending)

          BenefitsIntakeStatusJob.new.perform

          pending_form_submissions.reload.each do |form_submission|
            expect(form_submission.status).to eq :success
          end
        end
      end

      it 'updates the status with error from the bulk status report endpoint' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_bulk_status_report_error') do
          pending_form_submissions = create_list(:form_submission, 2, :pending)

          BenefitsIntakeStatusJob.new.perform

          pending_form_submissions.reload.each do |form_submission|
            expect(form_submission.status).to eq :error
          end
        end
      end
    end
  end
end
