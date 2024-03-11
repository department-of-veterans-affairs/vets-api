# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::Form526DocumentUploadPollingJob, type: :job do
  before do
    Sidekiq::Job.clear_all
  end

  describe '#perform' do
    context 'retries exhausted' do
      it 'updates the exhaustion StatsD counter' do
        described_class.within_sidekiq_retries_exhausted_block do
          expect(StatsD).to receive(:increment).with('worker.lighthouse.poll_form_526_document_uploads.exhausted')
        end
      end

      it 'logs exhaustion metadata to the Rails logger' do
        sidekiq_exhaustion_metadata = {
          'jid' => '8675309',
          'error_class' => 'BROKESKI',
          'error_message' => 'We are going to need a bigger boat'
        }

        exhaustion_time = Time.new(1985, 10, 26).utc

        Timecop.freeze(exhaustion_time) do
          described_class.within_sidekiq_retries_exhausted_block(sidekiq_exhaustion_metadata) do
            expect(Rails.logger).to receive(:warn).with(
              'Lighthouse::Form526DocumentUploadPollingJob retries exhausted',
              {
                job_id: '8675309',
                error_class: 'BROKESKI',
                error_message: 'We are going to need a bigger boat',
                timestamp: exhaustion_time
              }
            )
          end
        end
      end
    end

    describe 'Documents Polling' do
      before do
        # We aren't stressing either of these services, just verifying we pass the right info to them
        allow(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call)
        allow(BenefitsDocuments::Form526::UpdateDocumentsStatusService).to receive(:call)
      end

      context 'for a pending document' do
        let(:polling_time) { DateTime.new(1985, 10, 26).utc }

        around do |example|
          Timecop.freeze(polling_time) do
            example.run
          end
        end

        context 'For a document that has not been polled in the last 24 hours' do
          let!(:unpolled_document) do
            create(
              :lighthouse526_document_upload,
              aasm_state: 'pending',
              status_last_polled_at: polling_time - 25.hours
            )
          end

          it 'polls Lighthouse for the document status' do
            expect(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).with(
              [unpolled_document.lighthouse_document_request_id]
            )

            described_class.new.perform
          end

          it 'updates the status_last_polled_at time on the document' do
            described_class.new.perform
            expect(unpolled_document.reload.status_last_polled_at).to eq(polling_time)
          end
        end

        context 'for a document that has been polled in the last 24 hours' do
          let!(:recently_polled_document) do
            create(
              :lighthouse526_document_upload,
              aasm_state: 'pending',
              status_last_polled_at: polling_time - 6.hours
            )
          end

          it 'does not poll Lighthouse for the document status' do
            expect(BenefitsDocuments::Form526::DocumentsStatusPollingService).not_to receive(:call).with(
              [recently_polled_document.lighthouse_document_request_id]
            )

            described_class.perform_async
          end

          it 'does not update the status_last_polled_at time on the document' do
            status_last_polled_at = recently_polled_document.status_last_polled_at
            described_class.new.perform

            expect(recently_polled_document.reload.status_last_polled_at).to eq(status_last_polled_at)
          end
        end
      end

      context 'for a document that has completed' do
        let!(:recently_completed_document) { create(:lighthouse526_document_upload, aasm_state: 'completed', status_last_polled_at: 5.hours.ago.utc) }

        it 'does not poll for the document status' do
          expect(BenefitsDocuments::Form526::DocumentsStatusPollingService).not_to receive(:call).with(
            [recently_completed_document.lighthouse_document_request_id]
          )

          described_class.perform_async
        end
      end

      context 'for a document that has failed' do
        let!(:recently_failed_document) { create(:lighthouse526_document_upload, aasm_state: 'failed', status_last_polled_at: 5.hours.ago.utc) }

        it 'does not poll for the document status' do
          expect(BenefitsDocuments::Form526::DocumentsStatusPollingService).not_to receive(:call).with(
            [recently_failed_document.lighthouse_document_request_id]
          )

          described_class.perform_async
        end
      end
    end
  end
end
