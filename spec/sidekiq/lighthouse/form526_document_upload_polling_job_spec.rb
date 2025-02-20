# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::Form526DocumentUploadPollingJob, type: :job do
  before do
    Sidekiq::Job.clear_all
    # NOTE: to re-record the VCR cassettes for these tests:
    # 1. Comment out the line below stubbing the token
    # 2. Include both a valid Lighthouse client_id and rsa_key in config/settings/test.local.yml:
    # lighthouse:
    #   auth:
    #     ccg:
    #       client_id: <MY CLIENT ID>
    #       rsa_key: <MY RSA KEY PATH>
    # To generate the above credentials refer to this tutorial:
    # https://developer.va.gov/explore/api/benefits-documents/client-credentials
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return('abcd1234')
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  describe '#perform' do
    shared_examples 'document status updates' do |state, request_id, cassette|
      around { |example| VCR.use_cassette(cassette, match_requests_on: [:body]) { example.run } }

      let!(:document) { create(:lighthouse526_document_upload, lighthouse_document_request_id: request_id) }

      it 'updates document status' do
        described_class.new.perform
        expect(document.reload.aasm_state).to eq(state)
        expect(document.reload.lighthouse_processing_ended_at).not_to be_nil
        expect(document.reload.last_status_response).not_to be_nil
      end

      it 'saves the status_last_polled_at time' do
        polling_time = DateTime.new(1985, 10, 26).utc
        Timecop.freeze(polling_time) do
          described_class.new.perform
          expect(document.reload.status_last_polled_at).to eq(polling_time)
        end
      end
    end

    # End-to-end integration test - completion
    context 'for a document that has completed' do
      # Completed Lighthouse QA environment document requestId provided by Lighthouse for end-to-end testing
      it_behaves_like 'document status updates', 'completed', '22',
                      'lighthouse/benefits_claims/documents/form526_document_upload_status_complete'
    end

    context 'for a document that has failed' do
      # Failed Lighthouse QA environment document requestId provided by Lighthouse for end-to-end testing
      it_behaves_like 'document status updates', 'failed', '16819',
                      'lighthouse/benefits_claims/documents/form526_document_upload_status_failed'
    end

    context 'for a single document request whose status is not found' do
      # Non-existent Lighthouse QA environment document requestId
      let!(:unknown_document) { create(:lighthouse526_document_upload, lighthouse_document_request_id: '21') }
      let(:error_body) do
        { 'errors' => [{ 'detail' => 'Upload Request Async Status Not Found', 'status' => 404,
                         'title' => 'Not Found', 'instance' => '062dd917-a229-42d7-ad39-741eb81766a8',
                         'diagnostics' => '7YODuWbVvC0k+iFgaQC0SrlARmYKPKz4' }] }
      end

      around do |example|
        VCR.use_cassette('lighthouse/benefits_claims/documents/form526_document_upload_status_not_found',
                         match_requests_on: [:body]) do
          example.run
        end
      end

      it 'increments a StatsD counter and logs error' do
        expect(StatsD).to receive(:increment).with('worker.lighthouse.poll_form526_document_uploads.polling_error')

        Timecop.freeze(Time.new(1985, 10, 26).utc) do
          expect(Rails.logger).to receive(:warn).with(
            'Lighthouse::Form526DocumentUploadPollingJob status endpoint error',
            hash_including(response_status: 404, response_body: error_body,
                           lighthouse_document_request_ids: [unknown_document.lighthouse_document_request_id])
          )
          described_class.new.perform
        end
      end
    end

    context 'for a document with status and another document whose request id is not found' do
      let!(:complete_document) { create(:lighthouse526_document_upload, lighthouse_document_request_id: '22') }
      let!(:unknown_document) { create(:lighthouse526_document_upload, lighthouse_document_request_id: '21') }

      around do |example|
        VCR.use_cassette('lighthouse/benefits_claims/documents/form526_document_upload_with_request_ids_not_found',
                         match_requests_on: [:body]) do
          example.run
        end
      end

      it 'increments StatsD counters for both documents and logs unknown document error' do
        expect(StatsD).to receive(:increment)
          .with('api.form526.lighthouse_document_upload_processing_status.bdd_instructions.complete').ordered
        expect(StatsD).to receive(:increment)
          .with('worker.lighthouse.poll_form526_document_uploads.polling_error').ordered

        Timecop.freeze(Time.new(1985, 10, 26).utc) do
          expect(Rails.logger).to receive(:warn).with(
            'Lighthouse::Form526DocumentUploadPollingJob status endpoint error',
            hash_including(response_status: 404, response_body: 'Upload Request Async Status Not Found',
                           lighthouse_document_request_ids: [unknown_document.lighthouse_document_request_id])
          )
          described_class.new.perform
        end
      end
    end

    context 'non-200 failure response from Lighthouse' do
      let!(:pending_document) { create(:lighthouse526_document_upload) }
      # Error body example from: https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current
      let(:error_body) { { 'errors' => [{ 'detail' => 'Code must match \'^[A-Z]{2}$\'', 'status' => 400 }] } }
      let(:error_response) { Faraday::Response.new(response_body: error_body, status: 400) }

      before do
        allow(BenefitsDocuments::Form526::DocumentsStatusPollingService)
          .to receive(:call).and_return(error_response)
      end

      it 'increments a StatsD counter and logs error' do
        expect(StatsD).to receive(:increment).with('worker.lighthouse.poll_form526_document_uploads.polling_error')

        Timecop.freeze(Time.new(1985, 10, 26).utc) do
          expect(Rails.logger).to receive(:warn).with(
            'Lighthouse::Form526DocumentUploadPollingJob status endpoint error',
            hash_including(response_status: 400, response_body: error_body,
                           lighthouse_document_request_ids: [pending_document.lighthouse_document_request_id])
          )
          described_class.new.perform
        end
      end
    end

    context 'retries exhausted' do
      it 'updates the exhaustion StatsD counter' do
        described_class.within_sidekiq_retries_exhausted_block do
          expect(StatsD).to receive(:increment).with('worker.lighthouse.poll_form526_document_uploads.exhausted')
        end
      end

      it 'logs exhaustion metadata to the Rails logger' do
        exhaustion_time = DateTime.new(1985, 10, 26).utc
        sidekiq_exhaustion_metadata = { 'jid' => 8_675_309, 'error_class' => 'BROKESKI',
                                        'error_message' => 'We are going to need a bigger boat' }
        Timecop.freeze(exhaustion_time) do
          described_class.within_sidekiq_retries_exhausted_block(sidekiq_exhaustion_metadata) do
            expect(Rails.logger).to receive(:warn).with(
              'Lighthouse::Form526DocumentUploadPollingJob retries exhausted',
              {
                job_id: 8_675_309,
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
      let(:faraday_response) { instance_double(Faraday::Response, body: {}, status: 200) }
      let(:polling_service) { BenefitsDocuments::Form526::DocumentsStatusPollingService }
      let(:polling_time) { DateTime.new(1985, 10, 26).utc }

      before do
        # Verifies correct info is being passed to both services
        allow(BenefitsDocuments::Form526::DocumentsStatusPollingService)
          .to receive(:call).and_return(faraday_response)
        allow(BenefitsDocuments::Form526::UpdateDocumentsStatusService)
          .to receive(:call).and_return(success: true, response: { status: 200 })
      end

      context 'for a pending document' do
        around { |example| Timecop.freeze(polling_time) { example.run } }

        it 'polls for unpolled and repoll documents' do
          documents = [
            create(:lighthouse526_document_upload),
            create(:lighthouse526_document_upload, status_last_polled_at: polling_time - 2.hours)
          ]
          document_request_ids = documents.map(&:lighthouse_document_request_id)

          expect(polling_service).to receive(:call).with(document_request_ids)
          described_class.new.perform
        end

        it 'does not poll for recently polled documents' do
          recently_polled_document = create(:lighthouse526_document_upload,
                                            status_last_polled_at: polling_time - 42.minutes)
          expect(polling_service).not_to receive(:call)
            .with([recently_polled_document.lighthouse_document_request_id])
          described_class.new.perform
        end
      end

      context 'for completed and failed documents' do
        let!(:documents) do
          [
            create(:lighthouse526_document_upload, aasm_state: 'completed',
                                                   status_last_polled_at: polling_time - 2.hours),
            create(:lighthouse526_document_upload, aasm_state: 'failed',
                                                   status_last_polled_at: polling_time - 2.hours)
          ]
        end

        it 'does not poll for completed or failed documents' do
          documents.each do |doc|
            expect(polling_service).not_to receive(:call).with([doc.lighthouse_document_request_id])
          end
          described_class.new.perform
        end
      end
    end

    describe 'Document Polling Logging' do
      context 'for pending documents' do
        let!(:pending_polling_documents) { create_list(:lighthouse526_document_upload, 2, aasm_state: 'pending') }
        let!(:pending_recently_polled_document) do
          create(
            :lighthouse526_document_upload,
            aasm_state: 'pending',
            status_last_polled_at: polling_time - 45.minutes
          )
        end

        let(:polling_time) { DateTime.new(1985, 10, 26).utc }
        let(:faraday_response) do
          instance_double(
            Faraday::Response,
            body: {
              'data' => {
                'statuses' => [
                  {
                    'requestId' => pending_polling_documents.first.lighthouse_document_request_id,
                    'time' => {
                      'startTime' => 1_502_199_000,
                      'endTime' => 1_502_199_000
                    },
                    'status' => 'SUCCESS'
                  }, {
                    'requestId' => pending_polling_documents[1].lighthouse_document_request_id,
                    'time' => {
                      'startTime' => 1_502_199_000,
                      'endTime' => 1_502_199_000
                    },
                    'status' => 'FAILED',
                    'error' => {
                      'detail' => 'Something went wrong',
                      'step' => 'BENEFITS_GATEWAY_SERVICE'
                    }
                  }
                ],
                'requestIdsNotFound' => [
                  0
                ]
              }
            },
            status: 200
          )
        end

        around { |example| Timecop.freeze(polling_time) { example.run } }

        before do
          allow(BenefitsDocuments::Form526::DocumentsStatusPollingService)
            .to receive(:call).and_return(faraday_response)

          # StatsD will receive multiple gauge calls in this code flow
          allow(StatsD).to receive(:gauge)
        end

        describe 'polled documents metric' do
          it 'increments a StatsD gauge metric with total documents polled, discluding recently polled documents' do
            expect(StatsD).to receive(:gauge)
              .with('worker.lighthouse.poll_form526_document_uploads.pending_documents_polled', 2)

            described_class.new.perform
          end
        end

        describe 'completed and failed documents' do
          let!(:existing_completed_documents) do
            create_list(:lighthouse526_document_upload, 2, aasm_state: 'completed')
          end

          let!(:existing_failed_documents) { create_list(:lighthouse526_document_upload, 2, aasm_state: 'failed') }

          it 'increments a StatsD gauge metric with the total number of documents marked complete' do
            # Should only count documents newly counted success
            expect(StatsD).to receive(:gauge)
              .with('worker.lighthouse.poll_form526_document_uploads.pending_documents_marked_completed', 1)
            described_class.new.perform
          end

          it 'increments a StatsD gauge metric with the total number of documents marked failed' do
            # Should only count documents newly counted failed
            expect(StatsD).to receive(:gauge)
              .with('worker.lighthouse.poll_form526_document_uploads.pending_documents_marked_failed', 1)
            described_class.new.perform
          end
        end
      end
    end
  end
end
