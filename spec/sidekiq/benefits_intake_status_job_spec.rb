# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitsIntakeStatusJob, type: :job do
  describe '#perform' do
    describe 'submission to the bulk status report endpoint' do
      it 'submits only pending form submissions' do
        pending_form_submission_ids = create_list(:form_submission, 2, :pending).map(&:benefits_intake_uuid)
        create_list(:form_submission, 2, :success)
        create_list(:form_submission, 2, :failure)
        response = double
        allow(response).to receive(:body).and_return({ 'data' => [] })
        expect_any_instance_of(BenefitsIntakeService::Service).to receive(:get_bulk_status_of_uploads)
          .with(pending_form_submission_ids).and_return(response)

        BenefitsIntakeStatusJob.new.perform
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
            expect(form_submission.status).to eq :failure
          end
        end
      end
    end
  end
end
