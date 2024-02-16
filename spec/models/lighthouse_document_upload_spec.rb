# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LighthouseDocumentUpload do
  # Example payload from Lighthouse Benefts Documents API /upload/status endpoint
  # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current
  let(:lighthouse_status_response) do
    {
      data: {
        statuses: [
          {
            requestId: '600000001',
            time: {
              startTime: '1502199000',
              endTime: '1502199000'
            },
            status: 'IN_PROGRESS',
            steps: [
              {
                name: 'BENEFITS_GATEWAY_SERVICE',
                nextStepName: 'BENEFITS_GATEWAY_SERVICE',
                description: 'string',
                status: 'NOT_STARTED'
              }
            ],
            error: {
              detail: 'string',
              step: 'BENEFITS_GATEWAY_SERVICE'
            }
          }
        ]
      }
    }
  end

  it 'is created with an initial aasm status of pending_vbms_submission' do
    expect(build(:lighthouse_document_upload).aasm_state).to eq('pending_vbms_submission')
  end

  context 'for a new record' do
    describe 'with valid attributes' do
      it 'is valid with a valid document_type' do
        ['BDD Instructions', 'Form 0781', 'Form 0781a', 'Veteran Upload'].each do |document_type|
          expect(build(:lighthouse_document_upload, document_type:)).to be_valid
        end
      end

      context 'with a document type that is not Veteran Upload' do
        it 'is valid without a form_attachment_id' do
          expect(build(:lighthouse_document_upload, document_type: 'BDD Instructions', form_attachment_id: nil))
            .to be_valid
        end
      end
    end

    describe 'with invalid attributes' do
      it 'is invalid without a form526_submission_id' do
        expect(build(:lighthouse_document_upload, form526_submission_id: nil)).not_to be_valid
      end

      it 'is invalid without a lighthouse_document_request_id' do
        expect(build(:lighthouse_document_upload, lighthouse_document_request_id: nil)).not_to be_valid
      end

      it 'is invalid without a document_type' do
        expect(build(:lighthouse_document_upload, document_type: nil)).not_to be_valid
      end

      it 'is invalid without a valid document_type' do
        expect(build(:lighthouse_document_upload, document_type: 'Grocery Shopping List')).not_to be_valid
      end

      context 'with a document_type of Veteran Upload' do
        it 'is invalid without a form_attachment_id' do
          expect(build(:lighthouse_document_upload, document_type: 'Veteran Upload', form_attachment_id: nil))
            .not_to be_valid
        end
      end
    end

    describe 'state transtions' do
      let(:lighthouse_document_upload) { create(:lighthouse_document_upload) }

      it 'transitions to a pending_bgs_submission state' do
        expect(lighthouse_document_upload)
          .to transition_from(:pending_vbms_submission).to(:pending_bgs_submission).on_event(
            :vbms_submission_complete, lighthouse_status_response
          )
      end

      it 'transitions to a complete state' do
        expect(lighthouse_document_upload)
          .to transition_from(:pending_bgs_submission).to(:complete).on_event(
            :bgs_submission_complete, lighthouse_status_response
          )
      end

      it 'transitions to a failed_vbms_submission state' do
        expect(lighthouse_document_upload)
          .to transition_from(:pending_vbms_submission).to(:failed_vbms_submission).on_event(
            :vbms_submission_failed, lighthouse_status_response
          )
      end

      it 'transitions to a failed_bgs_submission state' do
        expect(lighthouse_document_upload)
          .to transition_from(:pending_bgs_submission).to(:failed_bgs_submission).on_event(
            :bgs_submission_failed, lighthouse_status_response
          )
      end

      it 'cannot transiton from pending_vbms_submission to complete' do
        upload = create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission', form_attachment_id: nil)
        expect { upload.bgs_submission_complete(lighthouse_status_response) }.to raise_error(AASM::InvalidTransition)
      end

      context 'when the upload transitions to an intermediate state' do
        it 'can transition without a lighthouse_processing_ended_at value' do
          upload = create(
            :lighthouse_document_upload, aasm_state: 'pending_vbms_submission', lighthouse_processing_ended_at: nil
          )
          expect do
            upload.vbms_submission_complete(lighthouse_status_response)
          end.not_to raise_error(AASM::InvalidTransition)
        end

        it 'can transition without an error_message value' do
          upload = create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission', error_message: nil)
          expect do
            upload.pending_bgs_submission(lighthouse_status_response)
          end.not_to raise_error(AASM::InvalidTransition)
        end
      end

      context 'when the upload transitions to a complete state' do
        it 'cannot transition without a lighthouse_processing_ended_at value' do
          upload = create(
            :lighthouse_document_upload, aasm_state: 'pending_bgs_submission', lighthouse_processing_ended_at: nil
          )
          expect { upload.bgs_submission_complete(lighthouse_status_response) }.to raise_error(AASM::InvalidTransition)
        end
      end

      context 'when the upload transitions to a failure state' do
        context 'when the failure happened in the upload to VBMS' do
          it 'cannot transition without an error_message value' do
            upload = create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission', error_message: nil)
            expect { upload.vbms_submission_failed(lighthouse_status_response) }.to raise_error(AASM::InvalidTransition)
          end
        end

        context 'when the failure happened in the upload to BGS' do
          it 'cannot transition without an error_message value' do
            upload = create(:lighthouse_document_upload, aasm_state: 'pending_bgs_submission', error_message: nil)
            expect { upload.bgs_submission_failed(lighthouse_status_response) }.to raise_error(AASM::InvalidTransition)
          end
        end
      end
    end

    describe '#log_status_change' do
      let(:lighthouse_document_upload) { create(:lighthouse_document_upload) }

      it 'logs metadata on the transition when the upload transitions state' do
        transitioned_at = Time.zone.now
        Timecop.freeze(transitioned_at)

        expect(Rails.logger).to receive(:info).with(
          {
            form526_submission_id: lighthouse_document_upload.form526_submission_id,
            lighthouse_document_upload_id: lighthouse_document_upload.id,
            lighthouse_document_request_id: lighthouse_document_upload.lighthouse_document_request_id,
            error_message: lighthouse_document_upload.error_message,
            from_state: :pending_vbms_submission,
            to_state: :pending_bgs_submission,
            event: :vbms_submission_complete,
            transitioned_at:,
            lighthouse_status_response:
          }
        )

        lighthouse_document_upload.vbms_submission_complete(lighthouse_status_response)
      end
    end
  end
end
