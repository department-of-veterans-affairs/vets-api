# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::UploadBddInstructions, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    Flipper.disable(:disability_compensation_lighthouse_document_service_provider)
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:submission) do
    create(:form526_submission, :with_uploads,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           submitted_claim_id: '600130094')
  end

  describe 'perform' do
    let(:client) { double(:client) }
    let(:document_data) { double(:document_data) }
    let(:file_read) { File.read('lib/evss/disability_compensation_form/bdd_instructions.pdf') }

    before do
      allow(EVSS::DocumentsService)
        .to receive(:new)
        .and_return(client)
    end

    context 'when file_data exists' do
      it 'calls the documents service api with file body and document data' do
        expect(EVSSClaimDocument)
          .to receive(:new)
          .with(
            evss_claim_id: submission.submitted_claim_id,
            file_name: 'BDD_Instructions.pdf',
            tracked_item_id: nil,
            document_type: 'L023'
          )
          .and_return(document_data)

        subject.perform_async(submission.id)
        expect(client).to receive(:upload).with(file_read, document_data)
        described_class.drain
      end

      context 'with a timeout' do
        it 'logs a retryable error and re-raises the original error' do
          allow(client).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
          subject.perform_async(submission.id)
          expect(Form526JobStatus).to receive(:upsert).twice
          expect { described_class.drain }.to raise_error(EVSS::ErrorMiddleware::EVSSBackendServiceError)
        end
      end
    end
  end

  context 'catastrophic failure state' do
    describe 'when all retries are exhausted' do
      let!(:form526_submission) { create(:form526_submission) }
      let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 1) }

      it 'updates a StatsD counter and updates the status on an exhaustion event' do
        subject.within_sidekiq_retries_exhausted_block({ 'jid' => form526_job_status.job_id }) do
          expect(StatsD).to receive(:increment).with(subject::STATSD_KEY_PREFIX)
          expect(Rails).to receive(:logger).and_call_original
        end
        form526_job_status.reload
        expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
      end
    end
  end
end
