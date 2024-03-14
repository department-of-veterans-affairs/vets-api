# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::Form526DocumentUploadPollingJob, type: :job do
  before do
    Sidekiq::Job.clear_all
    # NOTE: to re-record the VCR cassettes for these tests:
    # 1. Comment out the line below stubbing the token
    # 2. Ensure you have both a valid Lighthouse client_id and rsa_key in your config/settings/test.local.yml:
    # lighthouse:
    #   auth:
    #     ccg:
    #       client_id: <MY CLIENT ID>
    #        rsa_key: <MY RSA KEY PATH>
    # To generate the above credentials refer to this tutorial:
    # https://developer.va.gov/explore/api/benefits-documents/client-credentials
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return('abcd1234')
  end

  describe '#perform' do
    # TODO: RESOLVING ISSUES WITH QA ENDPOINT WITH LIGHTHOUSE,
    # NEED TO ADDRESS BEFORE WE CAN RECORD VCR CASSETES FOR THESE TESTS

    # End-to-end integration test - completion
    # context 'for a document that has completed' do
    #   around do |example|
    #     VCR.use_cassette('lighthouse/benefits_claims/documents/form_526_document_upload_status_complete') do
    #       example.run
    #     end
    #   end

    #   let!(:lighthouse_complete_document) do
    #     create(
    #       :lighthouse526_document_upload,
    #       document_type: 'Veteran Upload',
    #       aasm_state: 'pending',
    #       # Completed Lighthouse QA environment document requestId provided to us by Lighthouse for end-to-end testing
    #       lighthouse_document_request_id: '18559',
    #       lighthouse_processing_ended_at: nil,
    #       last_status_response: nil,
    #       status_last_polled_at: nil
    #     )
    #   end

    #   it 'marks the document as completed' do
    #     expect { described_class.new.perform }.to change(lighthouse_complete_document, :aasm_state).to('completed')
    #   end

    #   it 'increments a StatsD completion counter for the document type' do
    #     expect { described_class.new.perform }.to trigger_statsd_increment(
    #       'api.form_526.lighthouse_document_upload_processing_status.veteran_upload.complete'
    #     )
    #   end

    #   it 'updates the completion time on the document' do
    #     described_class.new.perform
    #     expect(lighthouse_complete_document.lighthouse_processing_ended_at).not_to be_nil
    #   end

    #   it 'saves the last_status_response' do
    #     described_class.new.perform
    #     expect(lighthouse_complete_document.last_status_response).not_to be_nil
    #   end

    #   it 'saves the status_last_polled_at time' do
    #     polling_time = DateTime.new(1985, 10, 26).utc

    #     Timecop.freeze(polling_time) do
    #       described_class.new.perform
    #       expect(lighthouse_complete_document.status_last_polled_at).to eq(polling_time)
    #     end
    #   end
    # end

    # context 'for a document that has failed' do
    #   let!(:lighthouse_failed_document) do
    #     create(
    #       :lighthouse526_document_upload,
    #       document_type: 'Veteran Upload',
    #       aasm_state: 'pending',
    #       # Failed Lighthouse QA environment document requestId provided to us by Lighthouse for end-to-end testing
    #       lighthouse_document_request_id: '16819',
    #       lighthouse_processing_ended_at: nil,
    #       last_status_response: nil,
    #       status_last_polled_at: nil
    #     )
    #   end

    #   around do |example|
    #     VCR.use_cassette('lighthouse/benefits_claims/documents/form_526_document_upload_status_failed') do
    #       example.run
    #     end
    #   end

    #   it 'marks the document as failed' do
    #     expect { described_class.new.perform }.to change(lighthouse_failed_document, :aasm_state).to('failed')
    #   end

    #   it 'increments a StatsD completion counter for the document type' do
    #     # TODO: STATUS KEY MUST MATCH STEP THAT FAILED IN LIGHTHOUSE; NEED TO GET ENDPOINT WORKING FIRST
    #     expect { described_class.new.perform }.to trigger_statsd_increment(
    #       'api.form_526.lighthouse_document_upload_processing_status.veteran_upload.failed.<FAILING STEP>'
    #     )
    #   end

    #   it 'updates the completion time on the document' do
    #     described_class.new.perform
    #     expect(lighthouse_failed_document.lighthouse_processing_ended_at).not_to be_nil
    #   end

    #   it 'saves the last_status_response' do
    #     described_class.new.perform
    #     expect(lighthouse_failed_document.last_status_response).not_to be_nil
    #   end

    #   it 'saves the status_last_polled_at time' do
    #     polling_time = DateTime.new(1985, 10, 26).utc

    #     Timecop.freeze(polling_time) do
    #       described_class.new.perform
    #       expect(lighthouse_failed_document.status_last_polled_at).to eq(polling_time)
    #     end
    #   end
    # end

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

        context 'for a document that has never been polled' do
          let!(:unpolled_document) do
            create(
              :lighthouse526_document_upload,
              aasm_state: 'pending',
              status_last_polled_at: nil
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

        context 'For a document that has not been polled in the last 24 hours' do
          let!(:pending_repoll_document) do
            create(
              :lighthouse526_document_upload,
              aasm_state: 'pending',
              status_last_polled_at: polling_time - 25.hours
            )
          end

          it 'polls Lighthouse for the document status' do
            expect(BenefitsDocuments::Form526::DocumentsStatusPollingService).to receive(:call).with(
              [pending_repoll_document.lighthouse_document_request_id]
            )

            described_class.new.perform
          end

          it 'updates the status_last_polled_at time on the document' do
            described_class.new.perform
            expect(pending_repoll_document.reload.status_last_polled_at).to eq(polling_time)
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
