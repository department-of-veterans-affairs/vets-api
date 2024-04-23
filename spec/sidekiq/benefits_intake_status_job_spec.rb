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

    describe 'when batch size is less than or equal to max batch size' do
      it 'successfully submits batch intake' do
        pending_form_submission_ids = create_list(:form_submission, 2, :pending).map(&:benefits_intake_uuid)
        response = double
        allow(response).to receive(:body).and_return({ 'data' => [] })

        expect_any_instance_of(BenefitsIntakeService::Service).to receive(:get_bulk_status_of_uploads)
          .with(pending_form_submission_ids).and_return(response)

        BenefitsIntakeStatusJob.new.perform
      end
    end

    describe 'when batch size is greater than max batch size' do
      it 'successfully submits batch intake via batch' do
        create_list(:form_submission, 4, :pending)
        response = double
        service = double(get_bulk_status_of_uploads: response)
        allow(response).to receive(:body).and_return({ 'data' => [] })
        allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)

        BenefitsIntakeStatusJob.new(max_batch_size: 2).perform

        expect(service).to have_received(:get_bulk_status_of_uploads).twice
      end
    end

    describe 'when bulk status update fails' do
      it 'logs the error' do
        create_list(:form_submission, 2, :pending)
        service = double
        message = 'error'
        allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
        allow(service).to receive(:get_bulk_status_of_uploads).and_raise(message)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        BenefitsIntakeStatusJob.new.perform

        expect(Rails.logger).to have_received(:error).with('Error processing Intake Status batch',
                                                           class: 'BenefitsIntakeStatusJob', message:)
        expect(Rails.logger).not_to have_received(:info).with('BenefitsIntakeStatusJob ended')
      end
    end

    describe 'updating the form submission status' do
      it 'updates the status with vbms from the bulk status report endpoint' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_bulk_status_report_success') do
          pending_form_submissions = create_list(:form_submission, 1, :pending)

          BenefitsIntakeStatusJob.new.perform

          pending_form_submissions.each do |form_submission|
            expect(form_submission.form_submission_attempts.first.reload.aasm_state).to eq 'vbms'
          end
        end
      end

      it 'updates the status with error from the bulk status report endpoint' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_bulk_status_report_error') do
          pending_form_submissions = create_list(:form_submission, 1, :pending)

          BenefitsIntakeStatusJob.new.perform

          pending_form_submissions.each do |form_submission|
            expect(form_submission.form_submission_attempts.first.reload.aasm_state).to eq 'failure'
          end
        end
      end
    end
  end
end
