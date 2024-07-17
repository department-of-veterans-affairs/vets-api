# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526StatusPollingJob, type: :job do
  describe '#perform' do
    let!(:new_submission) { create(:form526_submission) }
    let!(:backup_submission_a) { create(:form526_submission, :backup_path) }
    let!(:backup_submission_b) { create(:form526_submission, :backup_path) }
    let!(:backup_submission_c) { create(:form526_submission, :backup_path) }
    let!(:backup_submission_d) { create(:form526_submission, :backup_path) }
    let!(:paranoid_submission_a) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:paranoid_submission_b) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:paranoid_submission_c) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:old_paranoid_submission) do
      Timecop.freeze((1.year + 1.day).ago) do
        create(:form526_submission, :backup_path, :paranoid_success)
      end
    end
    let!(:accepted_backup_submission) do
      create(:form526_submission, :backup_path, :backup_accepted)
    end
    let!(:rejected_backup_submission) do
      create(:form526_submission, :backup_path, :backup_rejected)
    end

    context 'polling on parnoid success type submissions' do
      let(:api_response) do
        {
          'data' => [
            {
              'id' => paranoid_submission_a.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission_a.backup_submitted_claim_id,
                'status' => 'success'
              }
            },
            {
              'id' => paranoid_submission_b.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission_b.backup_submitted_claim_id,
                'status' => 'processing'
              }
            },
            {
              'id' => paranoid_submission_c.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission_c.backup_submitted_claim_id,
                'status' => 'error'
              }
            }
          ]
        }
      end

      describe 'submission to the bulk status report endpoint' do
        it 'submits only paranoid_success form submissions' do
          paranoid_claim_ids = Form526Submission.paranoid_success_type.pluck(:backup_submitted_claim_id)
          response = double
          allow(response).to receive(:body).and_return(api_response)
          allow_any_instance_of(BenefitsIntakeService::Service)
            .to receive(:get_bulk_status_of_uploads)
            .with(paranoid_claim_ids)
            .and_return(response)

          expect(paranoid_claim_ids).to contain_exactly(
            paranoid_submission_a.backup_submitted_claim_id,
            paranoid_submission_b.backup_submitted_claim_id,
            paranoid_submission_c.backup_submitted_claim_id
          )

          expect_any_instance_of(BenefitsIntakeService::Service)
            .to receive(:get_bulk_status_of_uploads)
            .with(paranoid_claim_ids)
            .and_return(response)

          Form526StatusPollingJob.new(paranoid: true).perform
        end
      end

      describe 'updating changed states' do
        it 'updates paranoid submissions to their correct state' do
          paranoid_claim_ids = Form526Submission.paranoid_success_type.pluck(:backup_submitted_claim_id)
          response = double
          allow(response).to receive(:body).and_return(api_response)
          allow_any_instance_of(BenefitsIntakeService::Service)
            .to receive(:get_bulk_status_of_uploads)
            .with(paranoid_claim_ids)
            .and_return(response)

          expect(paranoid_claim_ids).to contain_exactly(
            paranoid_submission_a.backup_submitted_claim_id,
            paranoid_submission_b.backup_submitted_claim_id,
            paranoid_submission_c.backup_submitted_claim_id
          )

          Form526StatusPollingJob.new(paranoid: true).perform
          paranoid_submission_a.reload
          paranoid_submission_b.reload
          paranoid_submission_c.reload

          expect(paranoid_submission_a.backup_submitted_claim_status).to eq 'paranoid_success'
          expect(paranoid_submission_b.backup_submitted_claim_status).to eq nil
          expect(paranoid_submission_c.backup_submitted_claim_status).to eq 'rejected'
        end
      end
    end

    context 'polling on pending submissions' do
      describe 'submission to the bulk status report endpoint' do
        it 'submits only pending form submissions' do
          pending_claim_ids = Form526Submission.pending_backup.pluck(:backup_submitted_claim_id)
          response = double
          allow(response).to receive(:body).and_return({ 'data' => [] })

          expect(pending_claim_ids).to contain_exactly(
            backup_submission_a.backup_submitted_claim_id,
            backup_submission_b.backup_submitted_claim_id,
            backup_submission_c.backup_submitted_claim_id,
            backup_submission_d.backup_submitted_claim_id
          )

          expect_any_instance_of(BenefitsIntakeService::Service)
            .to receive(:get_bulk_status_of_uploads)
            .with(pending_claim_ids)
            .and_return(response)

          Form526StatusPollingJob.new.perform
        end
      end

      describe 'when batch size is greater than max batch size' do
        it 'successfully submits batch intake via batch' do
          response = double
          service = double(get_bulk_status_of_uploads: response)
          allow(response).to receive(:body).and_return({ 'data' => [] })
          allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)

          Form526StatusPollingJob.new(max_batch_size: 3).perform

          expect(service).to have_received(:get_bulk_status_of_uploads).twice
        end
      end

      describe 'when bulk status update fails' do
        it 'logs the error' do
          service = double
          message = 'error'
          allow(BenefitsIntakeService::Service).to receive(:new).and_return(service)
          allow(service).to receive(:get_bulk_status_of_uploads).and_raise(message)
          allow(Rails.logger).to receive(:info)
          allow(Rails.logger).to receive(:error)

          Form526StatusPollingJob.new.perform

          expect(Rails.logger)
            .to have_received(:error)
            .with(
              'Error processing 526 Intake Status batch',
              class: 'Form526StatusPollingJob',
              message:,
              paranoid: false
            )
          expect(Rails.logger)
            .not_to have_received(:info).with('Form 526 Intake Status polling complete')
        end
      end

      describe 'updating the form 526s local submission state' do
        let(:api_response) do
          {
            'data' => [
              {
                'id' => backup_submission_a.backup_submitted_claim_id,
                'attributes' => {
                  'guid' => backup_submission_a.backup_submitted_claim_id,
                  'status' => 'vbms'
                }
              },
              {
                'id' => backup_submission_b.backup_submitted_claim_id,
                'attributes' => {
                  'guid' => backup_submission_b.backup_submitted_claim_id,
                  'status' => 'success'
                }
              },
              {
                'id' => backup_submission_c.backup_submitted_claim_id,
                'attributes' => {
                  'guid' => backup_submission_c.backup_submitted_claim_id,
                  'status' => 'error'
                }
              },
              {
                'id' => backup_submission_d.backup_submitted_claim_id,
                'attributes' => {
                  'guid' => backup_submission_d.backup_submitted_claim_id,
                  'status' => 'expired'
                }
              }
            ]
          }
        end

        it 'updates local state to reflect the returned statuses' do
          pending_claim_ids = Form526Submission.pending_backup
                                               .pluck(:backup_submitted_claim_id)
          response = double

          allow(response).to receive(:body).and_return(api_response)
          allow_any_instance_of(BenefitsIntakeService::Service)
            .to receive(:get_bulk_status_of_uploads)
            .with(pending_claim_ids)
            .and_return(response)

          Form526StatusPollingJob.new.perform

          expect(backup_submission_a.reload.backup_submitted_claim_status).to eq 'accepted'
          expect(backup_submission_b.reload.backup_submitted_claim_status).to eq 'paranoid_success'
          expect(backup_submission_c.reload.backup_submitted_claim_status).to eq 'rejected'
          expect(backup_submission_d.reload.backup_submitted_claim_status).to eq 'rejected'
        end
      end
    end
  end
end
