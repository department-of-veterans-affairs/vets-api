# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

RSpec.describe Lighthouse::EvidenceSubmissions::EvidenceSubmissionDocumentUploadPollingJob, type: :job do
  let(:job) { described_class.perform_async }
  let(:user_account) { create(:user_account) }
  let(:user_account_uuid) { user_account.id }
  let(:current_date_time) { DateTime.current }
  let!(:pending_lighthouse_document_upload1) do
    create(:bd_evidence_submission_pending, job_class: 'BenefitsDocuments::Service', request_id: 1)
  end
  let!(:pending_lighthouse_document_upload2) do
    create(:bd_evidence_submission_pending, job_class: 'BenefitsDocuments::Service', request_id: 2)
  end

  let!(:pending_lighthouse_document_upload_no_request_id) do
    create(:bd_evidence_submission_pending, job_class: 'BenefitsDocuments::Service', request_id: nil)
  end

  let(:error_message) do
    {
      'detail' => 'string',
      'step' => 'BENEFITS_GATEWAY_SERVICE'
    }
  end
  let(:issue_instant) { Time.current.to_i }
  let(:date_failed) do
    BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
  end

  context 'when there are EvidenceSubmission records' do
    before do
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
    end

    it 'polls and updates status for each EvidenceSubmission record that is still pending to "complete"' do
      VCR.use_cassette('lighthouse/benefits_claims/documents/lighthouse_document_upload_status_polling_success') do
        Timecop.freeze(current_date_time) do
          job
          described_class.drain
        end
      end
      pending_es = EvidenceSubmission.where(request_id: 1).first
      pending_es2 = EvidenceSubmission.where(request_id: 2).first
      expect(pending_es.completed?).to be(true)
      expect(pending_es.delete_date).to be_within(1.second).of((current_date_time + 60.days))

      expect(pending_es2.completed?).to be(true)
      expect(pending_es2.delete_date).to be_within(1.second).of((current_date_time + 60.days))

      expect(pending_lighthouse_document_upload_no_request_id.completed?).to be(false)

      expect(StatsD).to have_received(:increment).with(
        'worker.lighthouse.cst_document_uploads.pending_documents_polled', 2
      )
      expect(StatsD).to have_received(:increment).with(
        'worker.lighthouse.cst_document_uploads.pending_documents_marked_completed', 2
      )
      expect(StatsD).to have_received(:increment).with(
        'worker.lighthouse.cst_document_uploads.pending_documents_marked_failed', 0
      )
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
      expect(pending_es.failed?).to be(true)
      expect(pending_es.acknowledgement_date).to be_within(1.second).of((current_date_time + 30.days))
      expect(pending_es.failed_date).to be_within(1.second).of(current_date_time)
      expect(pending_es.error_message).to eq(error_message.to_s)
      expect(JSON.parse(pending_es.template_metadata)['personalisation']['date_failed']).to eq(date_failed)

      expect(pending_es2.failed?).to be(true)
      expect(pending_es2.acknowledgement_date).to be_within(1.second).of((current_date_time + 30.days))
      expect(pending_es2.failed_date).to be_within(1.second).of(current_date_time)
      expect(pending_es2.error_message).to eq(error_message.to_s)
      expect(JSON.parse(pending_es2.template_metadata)['personalisation']['date_failed']).to eq(date_failed)

      expect(StatsD).to have_received(:increment).with(
        'worker.lighthouse.cst_document_uploads.pending_documents_polled', 2
      )
      expect(StatsD).to have_received(:increment).with(
        'worker.lighthouse.cst_document_uploads.pending_documents_marked_completed', 0
      )
      expect(StatsD).to have_received(:increment).with(
        'worker.lighthouse.cst_document_uploads.pending_documents_marked_failed', 2
      )
    end
  end
end
