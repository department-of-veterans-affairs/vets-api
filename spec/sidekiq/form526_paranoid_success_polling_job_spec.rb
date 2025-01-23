# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526ParanoidSuccessPollingJob, type: :job do
  describe '#perform' do
    let!(:new_submission) { create(:form526_submission) }
    let!(:backup_submission) { create(:form526_submission, :backup_path) }
    let!(:paranoid_submission1) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:paranoid_submission2) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:paranoid_submission3) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:paranoid_submission4) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:paranoid_submission5) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:paranoid_submission6) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:success_by_age) do
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

    context 'polling on paranoid success type submissions' do
      let(:api_response) do
        {
          'data' => [
            {
              'id' => paranoid_submission1.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission1.backup_submitted_claim_id,
                'status' => 'success'
              }
            },
            {
              'id' => paranoid_submission2.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission2.backup_submitted_claim_id,
                'status' => 'processing'
              }
            },
            {
              'id' => paranoid_submission3.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission3.backup_submitted_claim_id,
                'status' => 'error'
              }
            },
            {
              'id' => paranoid_submission4.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission4.backup_submitted_claim_id,
                'status' => 'expired'
              }
            },
            {
              'id' => paranoid_submission5.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission5.backup_submitted_claim_id,
                'status' => 'something_crazy'
              }
            },
            {
              'id' => paranoid_submission6.backup_submitted_claim_id,
              'attributes' => {
                'guid' => paranoid_submission6.backup_submitted_claim_id,
                'status' => 'vbms'
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
            paranoid_submission1.backup_submitted_claim_id,
            paranoid_submission2.backup_submitted_claim_id,
            paranoid_submission3.backup_submitted_claim_id,
            paranoid_submission4.backup_submitted_claim_id,
            paranoid_submission5.backup_submitted_claim_id,
            paranoid_submission6.backup_submitted_claim_id
          )

          expect_any_instance_of(BenefitsIntakeService::Service)
            .to receive(:get_bulk_status_of_uploads)
            .with(paranoid_claim_ids)
            .and_return(response)

          Form526ParanoidSuccessPollingJob.new.perform
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
            paranoid_submission1.backup_submitted_claim_id,
            paranoid_submission2.backup_submitted_claim_id,
            paranoid_submission3.backup_submitted_claim_id,
            paranoid_submission4.backup_submitted_claim_id,
            paranoid_submission5.backup_submitted_claim_id,
            paranoid_submission6.backup_submitted_claim_id
          )

          Form526ParanoidSuccessPollingJob.new.perform
          paranoid_submission1.reload
          paranoid_submission2.reload
          paranoid_submission3.reload
          paranoid_submission4.reload
          paranoid_submission5.reload
          paranoid_submission6.reload

          expect(paranoid_submission1.backup_submitted_claim_status).to eq 'paranoid_success'
          expect(paranoid_submission2.backup_submitted_claim_status).to be_nil
          expect(paranoid_submission3.backup_submitted_claim_status).to eq 'rejected'
          expect(paranoid_submission4.backup_submitted_claim_status).to eq 'rejected'
          expect(paranoid_submission5.backup_submitted_claim_status).to eq 'rejected'
          expect(paranoid_submission6.backup_submitted_claim_status).to eq 'accepted'
        end
      end
    end
  end
end
