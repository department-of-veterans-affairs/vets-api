# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/worker_service'
require 'lighthouse/benefits_documents/service'
require 'lighthouse/benefits_documents/form_526_lighthouse_documents_service'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  subject { described_class }

  describe 'perform' do
    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:saved_claim) { FactoryBot.create(:va526ez) }
    let(:document_data) { double(:document_data, valid?: true) }

    before do
      Sidekiq::Worker.clear_all
    end

    # Legacy EVSS upload flow
    context 'when the disability_compensation_lighthouse_document_service_provider flipper is disabled' do
      before do
        Flipper.disable(:disability_compensation_lighthouse_document_service_provider)
      end

      let(:auth_headers) do
        EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
      end

      let(:submission) do
        create(
          :form526_submission,
          :with_uploads,
          user_uuid: user.uuid,
          auth_headers_json: auth_headers.to_json,
          saved_claim_id: saved_claim.id,
          submitted_claim_id: '600130094'
        )
      end

      let(:upload_data) { [submission.form[Form526Submission::FORM_526_UPLOADS].first] }

      context 'when file_data exists' do
        let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', 'image/jpg') }
        let!(:attachment) do
          sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
          sea.set_file_data!(file)
          sea.save!
        end

        it 'calls the documents service api with file body and document data' do
          VCR.use_cassette('evss/documents/upload_with_errors') do
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
            expect_any_instance_of(EVSS::DocumentsService).to receive(:upload).with(file.read, document_data)
            described_class.drain
          end
        end

        context 'with a timeout' do
          it 'logs a retryable error and re-raises the original error' do
            allow_any_instance_of(EVSS::DocumentsService).to receive(:upload)
              .and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
            subject.perform_async(submission.id, upload_data)
            expect(Form526JobStatus).to receive(:upsert).twice
            expect { described_class.drain }.to raise_error(EVSS::ErrorMiddleware::EVSSBackendServiceError)
          end
        end
      end

      context 'when misnamed file_data exists' do
        let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1_actually_jpg.png', 'image/png') }
        let!(:attachment) do
          sea = SupportingEvidenceAttachment.new(guid: upload_data.first['confirmationCode'])
          sea.set_file_data!(file)
          sea.save
        end

        it 'calls the documents service api with file body and document data' do
          VCR.use_cassette('evss/documents/upload_with_errors') do
            expect(EVSSClaimDocument)
              .to receive(:new)
              .with(
                evss_claim_id: submission.submitted_claim_id,
                file_name: 'converted_sm_file1_actually_jpg_png.jpg',
                tracked_item_id: nil,
                document_type: upload_data.first['attachmentId']
              )
              .and_return(document_data)

            subject.perform_async(submission.id, upload_data)
            expect_any_instance_of(EVSS::DocumentsService).to receive(:upload).with(file.read, document_data)
            described_class.drain
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

    # Lighthouse Document Upload flow
    context 'when the disability_compensation_lighthouse_document_service_provider flipper is enabled' do
      before do
        Flipper.enable(:disability_compensation_lighthouse_document_service_provider)
      end

      let(:submission) do
        create(
          :form526_submission,
          :with_uploads
        )
      end

      let(:first_submission_upload) { submission.form[Form526Submission::FORM_526_UPLOADS].first }
      let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', 'application/pdf') }

      let!(:attachment) do
        attachment = SupportingEvidenceAttachment.new(guid: first_submission_upload['confirmationCode'])
        attachment.set_file_data!(file)
        attachment.save!
        attachment
      end

      let(:upload_data) { { 'attachmentId' => 'L023', 'confirmationCode' => attachment.guid } }

      it 'uploads the document via the Form526LighthouseDocumentsService' do
        file_contents = attachment&.get_file&.read

        allow_any_instance_of(SupportingEvidenceAttachment).to receive(:converted_filename)
          .and_return('Doctors_Note.pdf')

        expect_any_instance_of(EVSS::DisabilityCompensationForm::SubmitUploads).to receive(:upload_lighthouse_document)
          .with(
            file_contents,
            'Doctors_Note.pdf',
            submission,
            'L023'
          )

        subject.perform_async(submission.id, upload_data)
        described_class.drain
      end
    end
  end
end
