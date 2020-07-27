# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
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
    let(:upload_data) { [submission.form[Form526Submission::FORM_526_UPLOADS].first] }
    let(:client) { double(:client) }
    let(:document_data) { double(:document_data) }

    before do
      allow(EVSS::DocumentsService)
        .to receive(:new)
        .and_return(client)
      allow(SupportingEvidenceAttachment)
        .to receive(:find_by)
        .and_return(attachment)
    end

    context 'when file_data exists' do
      let(:attachment) { double(:attachment, get_file: file) }
      let(:file) { double(:file, read: 'file') }

      it 'calls the documents service api with file body and document data' do
        expect(EVSSClaimDocument)
          .to receive(:new)
          .with(
            evss_claim_id: submission.submitted_claim_id,
            file_name: upload_data.first['name'],
            tracked_item_id: nil,
            document_type: upload_data.first['attachmentId']
          )
          .and_return(document_data)

        subject.perform_async(submission.id, upload_data)
        expect(client).to receive(:upload).with(file.read, document_data)
        described_class.drain
      end

      context 'with a timeout' do
        it 'logs a retryable error and re-raises the original error' do
          allow(client).to receive(:upload).and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
          subject.perform_async(submission.id, upload_data)
          expect(Form526JobStatus).to receive(:upsert).twice
          expect { described_class.drain }.to raise_error(EVSS::ErrorMiddleware::EVSSBackendServiceError)
        end
      end
    end

    context 'when get_file is nil' do
      let(:attachment) { double(:attachment, get_file: nil) }

      it 'logs a non_retryable_error' do
        subject.perform_async(submission.id, upload_data)
        expect(Form526JobStatus).to receive(:upsert).twice
        expect { described_class.drain }.to raise_error(ArgumentError)
      end
    end
  end
end
