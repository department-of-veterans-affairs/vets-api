# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse526DocumentUpload do
  # Benefts Documents API /uploads/status endpoint payload examples available at:
  # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

  it 'is created with an initial aasm status of pending' do
    expect(build(:lighthouse526_document_upload).aasm_state).to eq('pending')
  end

  context 'for a new record' do
    describe 'with valid attributes' do
      it 'is valid with a valid document_type' do
        ['BDD Instructions', 'Form 0781', 'Form 0781a', 'Veteran Upload'].each do |document_type|
          expect(build(:lighthouse526_document_upload, document_type:)).to be_valid
        end
      end

      context 'with a document type that is not Veteran Upload' do
        it 'is valid without a form_attachment_id' do
          expect(build(:lighthouse526_document_upload, document_type: 'BDD Instructions', form_attachment_id: nil))
            .to be_valid
        end
      end
    end

    describe 'with invalid attributes' do
      it 'is invalid without a form526_submission_id' do
        expect(build(:lighthouse526_document_upload, form526_submission_id: nil)).not_to be_valid
      end

      it 'is invalid without a lighthouse_document_request_id' do
        expect(build(:lighthouse526_document_upload, lighthouse_document_request_id: nil)).not_to be_valid
      end

      it 'is invalid without a document_type' do
        expect(build(:lighthouse526_document_upload, document_type: nil)).not_to be_valid
      end

      it 'is invalid without a valid document_type' do
        expect(build(:lighthouse526_document_upload, document_type: 'Receipt')).not_to be_valid
      end

      context 'with a document_type of Veteran Upload' do
        it 'is invalid without a form_attachment_id' do
          expect(build(:lighthouse526_document_upload, document_type: 'Veteran Upload', form_attachment_id: nil))
            .not_to be_valid
        end
      end
    end

    describe 'state transtions' do
      # Both completed and failed uploads have an end time in Lighthouse
      let(:finished_lighthouse526_document_upload) do
        create(:lighthouse526_document_upload, lighthouse_processing_ended_at: DateTime.now)
      end

      it 'transitions to a completed state' do
        expect(finished_lighthouse526_document_upload).to transition_from(:pending).to(:completed).on_event(:complete!)
      end

      it 'transitions to a failed state' do
        expect(finished_lighthouse526_document_upload).to transition_from(:pending).to(:failed).on_event(:fail!)
      end

      describe 'transition guards' do
        context 'when transitioning to a completed state' do
          it 'transitions if lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: DateTime.now)
            expect { upload.complete! }.not_to raise_error
          end

          it 'does not transition if no lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: nil)
            expect { upload.complete! }.to raise_error(AASM::InvalidTransition)
          end
        end

        context 'when transitioning to a failed state' do
          it 'transitions if lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: DateTime.now)
            expect { upload.fail! }.not_to raise_error
          end

          it 'does not transition if no lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: nil)
            expect { upload.fail! }.to raise_error(AASM::InvalidTransition)
          end

          it 'transitions if error_message is saved' do
            upload = create(
              :lighthouse526_document_upload,
              lighthouse_processing_ended_at: DateTime.now,
              error_message: { status: 'Something broke' }.to_json
            )

            expect { upload.fail! }.not_to raise_error
          end

          it 'does not transition if no error_message is saved' do
            upload = create(:lighthouse526_document_upload, error_message: nil)
            expect { upload.fail! }.to raise_error(AASM::InvalidTransition)
          end

          context 'when disability_compensation_email_veteran_on_polled_lighthouse_doc_failure flipper is enabled' do
            before do
              Flipper.enable(:disability_compensation_email_veteran_on_polled_lighthouse_doc_failure)  # rubocop:disable Project/ForbidFlipperToggleInSpecs
            end

            context 'when the upload was a piece of veteran-supplied evidence' do
              let(:lighthouse526_document_upload) do
                create(
                  :lighthouse526_document_upload,
                  document_type: Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE,
                  lighthouse_processing_ended_at: DateTime.now,
                  error_message: { status: 'Something broke' }.to_json
                )
              end

              it 'enqueues a Form526DocumentUploadFailureEmail' do
                expect(EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail).to receive(:perform_async)
                lighthouse526_document_upload.fail!
              end
            end

            context 'when the upload was a Form 0781' do
              let(:lighthouse526_document_upload) do
                create(
                  :lighthouse526_document_upload,
                  document_type: Lighthouse526DocumentUpload::FORM_0781_DOCUMENT_TYPE,
                  lighthouse_processing_ended_at: DateTime.now,
                  error_message: { status: 'Something broke' }.to_json
                )
              end

              it 'enqueues a Form0781DocumentUploadFailureEmail' do
                expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail).to receive(:perform_async)
                lighthouse526_document_upload.fail!
              end
            end

            context 'when the upload was a Form 0781a' do
              let(:lighthouse526_document_upload) do
                create(
                  :lighthouse526_document_upload,
                  document_type: Lighthouse526DocumentUpload::FORM_0781A_DOCUMENT_TYPE,
                  lighthouse_processing_ended_at: DateTime.now,
                  error_message: { status: 'Something broke' }.to_json
                )
              end

              it 'enqueues a Form0781DocumentUploadFailureEmail' do
                expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail).to receive(:perform_async)
                lighthouse526_document_upload.fail!
              end
            end
          end

          context 'when disability_compensation_email_veteran_on_polled_lighthouse_doc_failure flipper is disabled' do
            before do
              Flipper.disable(:disability_compensation_email_veteran_on_polled_lighthouse_doc_failure) # rubocop:disable Project/ForbidFlipperToggleInSpecs
            end

            context 'when the upload was a piece of veteran-supplied evidence' do
              let(:lighthouse526_document_upload) do
                create(
                  :lighthouse526_document_upload,
                  document_type: Lighthouse526DocumentUpload::VETERAN_UPLOAD_DOCUMENT_TYPE,
                  lighthouse_processing_ended_at: DateTime.now,
                  error_message: { status: 'Something broke' }.to_json
                )
              end

              it 'enqueues a Form526DocumentUploadFailureEmail' do
                expect(EVSS::DisabilityCompensationForm::Form526DocumentUploadFailureEmail)
                  .not_to receive(:perform_async)

                lighthouse526_document_upload.fail!
              end
            end

            context 'when the upload was a Form 0781' do
              let(:lighthouse526_document_upload) do
                create(
                  :lighthouse526_document_upload,
                  document_type: Lighthouse526DocumentUpload::FORM_0781_DOCUMENT_TYPE,
                  lighthouse_processing_ended_at: DateTime.now,
                  error_message: { status: 'Something broke' }.to_json
                )
              end

              it 'enqueues a Form0781DocumentUploadFailureEmail' do
                expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail)
                  .not_to receive(:perform_async)

                lighthouse526_document_upload.fail!
              end
            end

            context 'when the upload was a Form 0781a' do
              let(:lighthouse526_document_upload) do
                create(
                  :lighthouse526_document_upload,
                  document_type: Lighthouse526DocumentUpload::FORM_0781A_DOCUMENT_TYPE,
                  lighthouse_processing_ended_at: DateTime.now,
                  error_message: { status: 'Something broke' }.to_json
                )
              end

              it 'enqueues a Form0781DocumentUploadFailureEmail' do
                expect(EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail)
                  .not_to receive(:perform_async)

                lighthouse526_document_upload.fail!
              end
            end
          end
        end
      end
    end

    describe '#form0781_types?' do
      it 'returns true for Form 0781 and Form 0781a document types' do
        ['Form 0781', 'Form 0781a'].each do |document_type|
          upload = build(:lighthouse526_document_upload, document_type:)
          expect(upload.form0781_types?).to be(true)
        end
      end

      it 'returns false for other document types' do
        ['BDD Instructions', 'Veteran Upload'].each do |document_type|
          upload = build(:lighthouse526_document_upload, document_type:)
          expect(upload.form0781_types?).to be(false)
        end
      end
    end
  end
end
