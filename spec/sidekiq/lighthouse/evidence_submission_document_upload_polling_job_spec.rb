# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/constants'

RSpec.describe Lighthouse::EvidenceSubmissionDocumentUploadPollingJob, type: :job do
  let(:job) { described_class.perform_async(user_account_uuid) }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:pending_params) do
    {
      claim_id: 'claim-id',
      tracked_item_id: 'tracked-item-id',
      job_id: job,
      job_class: '',
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING],
      user_account_id: user_account_uuid
    }
  end
  let(:success_params) do
    {
      claim_id: 'claim-id',
      tracked_item_id: 'tracked-item-id',
      job_id: job,
      job_class: '',
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS],
      user_account_id: user_account_uuid
    }
  end
  let(:failed_params) do
    {
      claim_id: 'claim-id',
      tracked_item_id: 'tracked-item-id',
      job_id: job,
      job_class: '',
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
      user_account_id: user_account_uuid
    }
  end

  context 'When there are EvidenceSubmission records' do
    before do
      EvidenceSubmission.find_or_create_by(**pending_params)
      EvidenceSubmission.find_or_create_by(**success_params)
      EvidenceSubmission.find_or_create_by(**failed_params)
    end

    it 'polls and updates status for each EvidenceSubmission record that is still pending' do
      job
      described_class.drain
    end
  end
end
