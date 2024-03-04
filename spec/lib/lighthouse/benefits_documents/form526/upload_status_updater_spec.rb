# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/upload_status_updater'

RSpec.describe BenefitsDocuments::Form526::UploadStatusUpdater do
  let(:lighthouse_document_upload) { create(:lighthouse_document_upload) }

  describe '#failed?' do
    context 'if the document is in a failed state' do
      let(:failed_document_status) { { 'status': 'FAILED' } }

      it 'returns true' do
        status_updater = described_class.new(failed_document_status, lighthouse_document_upload)
        expect(status_updater.failed?).to eq(true)
      end
    end

    context 'if the document is not in a failed state' do
      let(:in_progress_status) { { 'status': 'IN_PROGRESS' } }

      it 'returns false' do
        status_updater = described_class.new(in_progress_status, lighthouse_document_upload)
        expect(status_updater.failed?).to eq(false)
      end
    end
  end

  describe '#completed?' do
    context 'if the document is in a completed state' do
      let(:completed_document_status) { { 'status': 'SUCCESS' } }

      it 'returns true' do
        status_updater = described_class.new(completed_document_status, lighthouse_document_upload)
        expect(status_updater.completed?).to eq(true)
      end
    end

    context 'if the document is not in a completed state' do
      let(:in_progress_status) { { 'status': 'IN_PROGRESS' } }

      it 'returns false' do
        status_updater = described_class.new(in_progress_status, lighthouse_document_upload)
        expect(status_updater.completed?).to eq(false)
      end
    end
  end

  describe '#update_status' do
    context 'when the document is pending submission to VBMS' do
      let(:vbms_pending_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission') }

      context 'when the document was successfully submitted to VBMS' do
        let(:vbms_submission_complete_status) do
          # think will need to change these keys possibly?
          {
            'status': 'IN_PROGRESS',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'SUCCESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'NOT_STARTED'
              }
            ]
          }
        end

        it 'transitions the document to a pending_bgs_submission state' do
          status_updater = described_class.new(vbms_submission_complete_status, vbms_pending_upload)
          expect { status_updater.update_status }.to change(vbms_pending_upload, :aasm_state)
            .from('pending_vbms_submission').to('pending_bgs_submission')
        end
      end

      context 'when the document is still pending submission to VBMS' do
        let(:vbms_submission_pending_status) do
          {
            'status': 'IN_PROGRESS',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'NOT_STARTED'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'NOT_STARTED'
              }
            ]
          }
        end

        it 'does not transition the document state' do
          status_updater = described_class.new(vbms_submission_pending_status, vbms_pending_upload)
          expect { status_updater.update_status }.not_to change(vbms_pending_upload, :aasm_state)
        end
      end

      context 'when the document is still being submitted to VBMS' do
        let(:vbms_submission_in_progress_status) do
          {
            'status': 'IN_PROGRESS',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'IN_PROGRESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'NOT_STARTED'
              }
            ]
          }
        end

        it 'does not transition the document state' do
          status_updater = described_class.new(vbms_submission_in_progress_status, vbms_pending_upload)
          expect { status_updater.update_status }.not_to change(vbms_pending_upload, :aasm_state)
        end
      end

      # Cover the case where the upload is marked pending_vbms_submission,
      # but both the VBMS and BGS uploads succeeded since we last polled
      context 'when the document was submitted to VBMS successfully and BGS successfully' do
        let(:submission_complete_status) do
          {
            'status': 'SUCCESS',
            'time': {
              'endTime': '499152060'
            },
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'SUCCESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'SUCCESS'
              }
            ]
          }
        end

        it 'transitions the document to the complete state' do
          status_updater = described_class.new(submission_complete_status, vbms_pending_upload)
          expect { status_updater.update_status }.to change(vbms_pending_upload, :aasm_state).to('complete')
        end
      end
    end

    context 'when the document is pending submission to BGS' do
      let(:bgs_pending_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_bgs_submission') }

      context 'when the document was successfully submitted to BGS' do
        # Lighthouse returns date times as UNIX timestamps
        let(:completion_time) { '499152060' }

        let(:bgs_submission_complete_status) do
          {
            'status': 'SUCCESS',
            'time': {
              'endTime': completion_time
            },
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'SUCCESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'SUCCESS'
              }
            ]
          }
        end

        it 'transitions the document to a complete state' do
          status_updater = described_class.new(bgs_submission_complete_status, bgs_pending_upload)
          expect { status_updater.update_status }.to change(bgs_pending_upload, :aasm_state)
            .from('pending_bgs_submission').to('complete')
        end

        it 'saves the lighthouse_processing_ended_at timestamp' do
          status_updater = described_class.new(bgs_submission_complete_status, bgs_pending_upload)
          expect { status_updater.update_status }.to change(bgs_pending_upload, :lighthouse_processing_ended_at)
            .to(DateTime.strptime(completion_time, '%s'))
        end
      end

      context 'when the document is still pending submission to BGS' do
        let(:vbms_submission_pending_status) do
          {
            'status': 'IN_PROGRESS',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'SUCCESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'NOT_STARTED'
              }
            ]
          }
        end

        it 'does not transition the document state' do
          status_updater = described_class.new(vbms_submission_pending_status, bgs_pending_upload)
          expect { status_updater.update_status }.not_to change(bgs_pending_upload, :aasm_state)
        end
      end

      context 'when the document is still being submitted to BGS' do
        let(:vbms_submission_in_progress_status) do
          {
            'status': 'IN_PROGRESS',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'SUCCESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'IN_PROGRESS'
              }
            ]
          }
        end

        it 'does not transition the document state' do
          status_updater = described_class.new(vbms_submission_in_progress_status, bgs_pending_upload)
          expect { status_updater.update_status }.not_to change(bgs_pending_upload, :aasm_state)
        end
      end
    end

    context 'when the upload failed' do
      context 'when the Lighthouse upload to VBMS failed' do
        let(:vbms_pending_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission') }

        let(:vbms_submission_failed_status) do
          {
            'status': 'FAILED',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'FAILED'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'NOT_STARTED'
              }
            ],
            'error': {
              'detail': 'VBMS System Outage',
              'step': 'CLAIMS_EVIDENCE'
            }
          }
        end

        it 'transitions the upload to the failed_vbms_submission state' do
          status_updater = described_class.new(vbms_submission_failed_status, vbms_pending_upload)
          expect { status_updater.update_status }.to change(vbms_pending_upload, :aasm_state)
            .from('pending_vbms_submission').to('failed_vbms_submission')
        end

        it 'saves an error message' do
          status_updater = described_class.new(vbms_submission_failed_status, vbms_pending_upload)
          expect { status_updater.update_status }.to change(vbms_pending_upload, :error_message)
            .to(
              {
                detail: 'VBMS System Outage',
                step: 'CLAIMS_EVIDENCE'
              }.to_json
            )
        end
      end

      context 'when the Lighthouse upload to BGS failed' do
        let(:pending_bgs_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_bgs_submission') }

        let(:bgs_submission_failed_status) do
          {
            'status': 'FAILED',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'SUCCESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'FAILED'
              }
            ],
            'error': {
              'detail': 'BGS System Outage',
              'step': 'BENEFITS_GATEWAY_SERVICE'
            }
          }
        end

        it 'transitions the upload to the failed_bgs_submission state' do
          status_updater = described_class.new(bgs_submission_failed_status, pending_bgs_upload)
          expect { status_updater.update_status }.to change(pending_bgs_upload, :aasm_state)
            .from('pending_bgs_submission').to('failed_bgs_submission')
        end

        it 'saves an error message' do
          status_updater = described_class.new(bgs_submission_failed_status, pending_bgs_upload)
          expect { status_updater.update_status }.to change(pending_bgs_upload, :error_message)
            .to(
              {
                'detail': 'BGS System Outage',
                'step': 'BENEFITS_GATEWAY_SERVICE'
              }.to_json
            )
        end
      end

      # NOTE: it's possible in between the last time we polled a document's status a VBMS submission completed
      # and the BGS submission failed. Because the document was marked pending_vbms_submission the last time we
      # polled, we need to ensure we allow transitioning the document state from pending_vbms_submission
      # to failed_bgs_submission even though we missed the VBMS completion transition in between
      context 'document pending_vbms_submission, BGS submission failed, but we missed the VBMS completion transition' do
        let(:vbms_pending_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission') }

        let(:bgs_submission_failed_status) do
          {
            'status': 'FAILED',
            'steps': [
              {
                'name': 'CLAIMS_EVIDENCE',
                'status': 'SUCCESS'
              },
              {
                'name': 'BENEFITS_GATEWAY_SERVICE',
                'status': 'FAILED'
              }
            ],
            'error': {
              'detail': 'BGS System Outage',
              'step': 'BENEFITS_GATEWAY_SERVICE'
            }
          }
        end

        it 'transitions from pending_vbms_submission to failed_bgs_submission' do
          status_updater = described_class.new(bgs_submission_failed_status, vbms_pending_upload)
          expect { status_updater.update_status }.to change(vbms_pending_upload, :aasm_state)
            .from('pending_vbms_submission').to('failed_bgs_submission')
        end
      end
    end
  end
end
