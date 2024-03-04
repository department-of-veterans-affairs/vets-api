# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse526DocumentUpload do
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
        expect(build(:lighthouse526_document_upload, document_type: 'Grocery Shopping List')).not_to be_valid
      end

      context 'with a document_type of Veteran Upload' do
        it 'is invalid without a form_attachment_id' do
          expect(build(:lighthouse526_document_upload, document_type: 'Veteran Upload', form_attachment_id: nil))
            .not_to be_valid
        end
      end
    end

    describe 'state transtions' do
      let(:lighthouse526_document_upload) { create(:lighthouse526_document_upload) }

      it 'transitions to a completed state' do
        expect(lighthouse526_document_upload)
          .to transition_from(:pending).to(:completed).on_event(:complete!)
      end

      it 'transitions to a failed state' do
        expect(lighthouse526_document_upload)
          .to transition_from(:pending).to(:failed).on_event(:fail!)
      end

      describe 'transition guards' do
        context 'when transitioning to a completed state' do
          it 'transitions if a lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: DateTime.now)
            expect { upload.complete! }.not_to raise_error(AASM::InvalidTransition)
          end

          it 'does not transition if no lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: nil)
            expect { upload.complete! }.to raise_error(AASM::InvalidTransition)
          end
        end

        context 'when transitioning to a failed state' do
          it 'transitions if a lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: DateTime.now)
            expect { upload.fail! }.not_to raise_error(AASM::InvalidTransition)
          end

          it 'does not transition if no lighthouse_processing_ended_at is saved' do
            upload = create(:lighthouse526_document_upload, lighthouse_processing_ended_at: nil)
            expect { upload.fail! }.to raise_error(AASM::InvalidTransition)
          end

          it 'transitions if an error message is saved' do
            upload = create(:lighthouse526_document_upload, error_message: {status: 'Something broke'}.to_json)
            expect { upload.fail! }.not_to raise_error(AASM::InvalidTransition)
          end

          it 'does not transition if no error message is saved' do
            upload = create(:lighthouse526_document_upload, error_message: nil)
            expect { upload.fail! }.to raise_error(AASM::InvalidTransition)
          end
        end
      end
    end
  end
end
