# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/upload_status_updater'

RSpec.describe Lighthouse::BenefitsDocuments::Form526::UploadStatusUpdater do
  let(:lighthouse_document_upload) { create(:lighthouse_document_upload) }

  describe '#failed?' do
    context 'if the document is in a failed state' do
      let(:failed_document_status) { { status: 'FAILED' } }

      it 'returns true' do
        status = described_class.new(failed_document_status, lighthouse_document_upload)
        expect(status.failed?).to eq(true)
      end
    end

    context 'if the document is not in a failed state' do
      let(:in_progress_status) { { status: 'IN_PROGRESS' } }

      it 'returns false' do
        status = described_class.new(in_progress_status, lighthouse_document_upload)
        expect(status.failed?).to eq(false)
      end
    end
  end

  describe '#completed?' do
    context 'if the document is in a completed state' do
      let(:completed_document_status) { { status: 'SUCCESS' } }

      it 'returns true' do
        status = described_class.new(completed_document_status, lighthouse_document_upload)
        expect(status.completed?).to eq(true)
      end
    end

    context 'if the document is not in a completed state' do
      let(:in_progress_status) { { status: 'IN_PROGRESS' } }

      it 'returns false' do
        status = described_class.new(in_progress_status, lighthouse_document_upload)
        expect(status.completed?).to eq(false)
      end
    end
  end

  describe '#progressed?' do
    context 'pending VBMS submission' do
      let(:lighthouse_document_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_vbms_submission') }

      context 'when the document has progressed status' do
        let(:vmbs_submission_complete_status) do
          {
            status: 'IN_PROGRESS',
            steps: [
              {
                name: 'CLAIMS_EVIDENCE',
                status: 'SUCCESS'
              }
            ]
          }
        end

        it 'returns true' do
          status = described_class.new(vmbs_submission_complete_status, lighthouse_document_upload)
          expect(status.progressed?).to eq(true)
        end
      end

      context 'when the document has not progressed status' do
        let(:vmbs_submission_in_progress_status) do
          {
            status: 'IN_PROGRESS',
            steps: [
              {
                name: 'CLAIMS_EVIDENCE',
                status: 'IN_PROGRESS'
              }
            ]
          }
        end

        it 'returns false' do
          status = described_class.new(vmbs_submission_in_progress_status, lighthouse_document_upload)
          expect(status.progressed?).to eq(false)
        end
      end
    end

    context 'pending BGS submission' do
      let(:lighthouse_document_upload) { create(:lighthouse_document_upload, aasm_state: 'pending_bgs_submission') }

      context 'when the document has progressed status' do
        let(:bgs_submission_complete_status) do
          {
            status: 'SUCCESS',
            steps: [
              {
                name: 'BENEFITS_GATEWAY_SERVICE',
                status: 'SUCCESS'
              }
            ]
          }
        end

        it 'returns true' do
          status = described_class.new(bgs_submission_complete_status, lighthouse_document_upload)
          expect(status.progressed?).to eq(true)
        end
      end

      context 'when the document has not progressed status' do
        let(:bgs_submission_in_progress_status) do
          {
            status: 'IN_PROGRESS',
            steps: [
              {
                name: 'BENEFITS_GATEWAY_SERVICE',
                status: 'IN_PROGRESS'
              }
            ]
          }
        end

        it 'returns false' do
          status = described_class.new(bgs_submission_in_progress_status, lighthouse_document_upload)
          expect(status.progressed?).to eq(false)
        end
      end
    end
  end
end
