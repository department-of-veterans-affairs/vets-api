# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/constants'

RSpec.describe Lighthouse::EvidenceSubmissionDocumentUploadPollingJob, type: :job do
  let(:job) { described_class.perform_async }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:current_date_time) { DateTime.current.utc }
  let(:pending_params) do
    {
      claim_id: 'claim-id1',
      tracked_item_id: 'tracked-item-id1',
      job_id: job,
      job_class: '',
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING],
      user_account_id: user_account_uuid
    }
  end
  let(:pending_params2) do
    {
      claim_id: 'claim-id2',
      tracked_item_id: 'tracked-item-id2',
      job_id: job,
      job_class: '',
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING],
      user_account_id: user_account_uuid
    }
  end
  let(:success_params) do
    {
      claim_id: 'claim-id3',
      tracked_item_id: 'tracked-item-id3',
      job_id: job,
      job_class: '',
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS],
      user_account_id: user_account_uuid
    }
  end
  let(:failed_params) do
    {
      claim_id: 'claim-id4',
      tracked_item_id: 'tracked-item-id4',
      job_id: job,
      job_class: '',
      upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
      user_account_id: user_account_uuid
    }
  end

  context 'When there are EvidenceSubmission records' do
    before do
      # TODO: investigate using factories instead of writing directly to the db in this test
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
      pending_es = EvidenceSubmission.find_or_create_by(**pending_params)
      pending_es.request_id = 1
      pending_es.save!
      pending_es2 = EvidenceSubmission.find_or_create_by(**pending_params2)
      pending_es2.request_id = 2
      pending_es2.save!
      success_es = EvidenceSubmission.find_or_create_by(**success_params)
      success_es.request_id = 3
      success_es.save!
      failed_es = EvidenceSubmission.find_or_create_by(**failed_params)
      failed_es.request_id = 4
      failed_es.save!
    end

    it 'polls and updates status for each EvidenceSubmission record that is still pending' do
      VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_status_polling_success') do
        job
        described_class.drain
      end
      pending_es = EvidenceSubmission.where(request_id: 1).first
      pending_es2 = EvidenceSubmission.where(request_id: 2).first
      expect(pending_es.completed?).to eq(true)
      expect(pending_es2.completed?).to eq(true)
    end

    it 'polls and updates status for each failed EvidenceSubmission to "failed"' do
      VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_status_polling_failed') do
        Timecop.freeze(current_date_time) do
          job
          described_class.drain
        end
      end
      pending_es = EvidenceSubmission.where(request_id: 1).first
      pending_es2 = EvidenceSubmission.where(request_id: 2).first
      expect(pending_es.failed?).to eq(true)
      expect(pending_es2.failed?).to eq(true)
      expect(pending_es.acknowledgement_date).to eq((current_date_time + 30.days).utc)
      expect(pending_es2.acknowledgement_date).to eq((current_date_time + 30.days).utc)
    end
  end
end
