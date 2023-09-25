# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::UploadBddInstructions, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
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
end
