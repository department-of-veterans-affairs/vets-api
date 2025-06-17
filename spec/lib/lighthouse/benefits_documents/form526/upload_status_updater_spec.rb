# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/upload_status_updater'

RSpec.describe BenefitsDocuments::Form526::UploadStatusUpdater do
  let(:lighthouse526_document_upload) { create(:lighthouse526_document_upload) }
  let(:past_date_time) { DateTime.new(1985, 10, 26) }

  describe '#update_status' do
    let(:lighthouse526_document_upload) do
      create(:lighthouse526_document_upload, lighthouse_processing_started_at: nil)
    end

    shared_examples 'status updater' do |status, start_time, end_time, expected_state, error_message = nil|
      # Lighthouse returns datetimes as UNIX timestamps in milliseconds
      let(:unix_start_time) { start_time }
      let(:unix_end_time) { end_time }
      let(:document_status) do
        {
          'status' => status,
          'time' => { 'startTime' => unix_start_time, 'endTime' => unix_end_time },
          'steps' => [
            {
              'name' => 'CLAIMS_EVIDENCE',
              # Even if the overall status is FAILED, individual steps may still be successful
              'status' => status == 'FAILED' ? 'SUCCESS' : status
            },
            {
              'name' => 'BENEFITS_GATEWAY_SERVICE',
              'status' => status == 'FAILED' ? 'FAILED' : status
            }
          ],
          'error' => error_message
        }.compact
      end
      let(:status_updater) { described_class.new(document_status, lighthouse526_document_upload) }

      it 'saves a lighthouse_processing_started_at time' do
        expect { status_updater.update_status }.to change(
          lighthouse526_document_upload, :lighthouse_processing_started_at
        ).to(Time.at(unix_start_time / 1000).utc.to_datetime)
      end

      it 'saves a lighthouse_processing_ended_at time' do
        if unix_end_time
          expect { status_updater.update_status }.to change(
            lighthouse526_document_upload, :lighthouse_processing_ended_at
          ).to(Time.at(unix_end_time / 1000).utc.to_datetime)
        end
      end

      it "transitions the document to a #{expected_state} state" do
        expect { status_updater.update_status }.to change(lighthouse526_document_upload, :aasm_state)
          .from('pending').to(expected_state)
      end

      it 'saves the last_status_response' do
        expect { status_updater.update_status }.to change(lighthouse526_document_upload, :last_status_response)
          .to(document_status)
      end

      it 'logs the latest_status_response to the Rails logger' do
        Timecop.freeze(past_date_time) do
          expect(Rails.logger).to receive(:info) do |message, _details|
            expect(message).to equal?(
              'SavedClaim::DisabilityCompensation::Form526AllClaim Skipping tracking PDF overflow'
            )
          end

          expect(Rails.logger).to receive(:info).with(
            'BenefitsDocuments::Form526::UploadStatusUpdater',
            status:,
            status_response: document_status,
            updated_at: past_date_time
          )

          status_updater.update_status
        end
      end

      it 'updates the status_last_polled_at time on the document' do
        Timecop.freeze(past_date_time) do
          status_updater.update_status

          expect(lighthouse526_document_upload.status_last_polled_at).to eq(past_date_time)
        end
      end

      if error_message
        it 'saves the error_message' do
          expect { status_updater.update_status }.to change(lighthouse526_document_upload, :error_message)
            .to(error_message)
        end
      end
    end

    context 'when the document is completed' do
      it_behaves_like('status updater', 'SUCCESS', 499_152_060, 499_153_000, 'completed')
    end

    context 'when the document has failed' do
      error_message = { 'detail' => 'BGS outage', 'step' => 'BENEFITS_GATEWAY_SERVICE' }

      it_behaves_like('status updater', 'FAILED', 499_152_060, 499_153_000, 'failed', error_message)
    end

    context 'when the document is in progress' do
      let(:lighthouse526_new_document_upload) do
        create(:lighthouse526_document_upload, lighthouse_processing_started_at: nil, last_status_response: nil)
      end

      let(:status_updater) do
        described_class.new(
          {
            'status' => 'IN_PROGRESS',
            'time' => { 'startTime' => 499_152_060, 'endTime' => nil },
            'steps' => [
              { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'IN_PROGRESS' },
              { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'NOT_STARTED' }
            ]
          },
          lighthouse526_new_document_upload
        )
      end

      it 'does not change the state of the document' do
        expect { status_updater.update_status }.not_to change(lighthouse526_new_document_upload, :aasm_state)
      end

      it 'saves a lighthouse_processing_started_at time' do
        expect do
          status_updater.update_status
        end.to change(lighthouse526_new_document_upload, :lighthouse_processing_started_at)
          .to(Time.at(499_152_060 / 1000).utc.to_datetime)
      end

      it 'saves the last_status_response' do
        expect { status_updater.update_status }.to change(lighthouse526_new_document_upload, :last_status_response)
          .to(
            'status' => 'IN_PROGRESS',
            'time' => { 'startTime' => 499_152_060, 'endTime' => nil },
            'steps' => [
              { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'IN_PROGRESS' },
              { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'NOT_STARTED' }
            ]
          )
      end

      it 'logs the latest_status_response to the Rails logger' do
        Timecop.freeze(past_date_time) do
          expect(Rails.logger).to receive(:info) do |message, _details|
            expect(message).to equal?(
              'SavedClaim::DisabilityCompensation::Form526AllClaim Skipping tracking PDF overflow'
            )
          end

          expect(Rails.logger).to receive(:info).with(
            'BenefitsDocuments::Form526::UploadStatusUpdater',
            status: 'IN_PROGRESS',
            status_response: {
              'status' => 'IN_PROGRESS',
              'time' => { 'startTime' => 499_152_060, 'endTime' => nil },
              'steps' => [
                { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'IN_PROGRESS' },
                { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'NOT_STARTED' }
              ]
            },
            updated_at: past_date_time
          )

          status_updater.update_status
        end
      end
    end
  end

  describe '#get_failure_step' do
    let(:failed_document_status) do
      {
        'status' => 'FAILED',
        'time' => { 'startTime' => 499_152_060, 'endTime' => 499_153_000 },
        'steps' => [
          { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'SUCCESS' },
          { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'FAILED' }
        ],
        'error' => { 'detail' => 'BGS outage', 'step' => 'BENEFITS_GATEWAY_SERVICE' }
      }
    end

    it 'returns the name of the step Lighthouse reported failed' do
      status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)
      expect(status_updater.get_failure_step).to eq('BENEFITS_GATEWAY_SERVICE')
    end
  end

  describe '#processing_timeout?' do
    shared_examples 'processing timeout' do |status, start_time, expected|
      it "returns #{expected}" do
        Timecop.freeze(past_date_time.utc) do
          status_updater = described_class.new(
            {
              'status' => status,
              'time' => { 'startTime' => start_time, 'endTime' => nil },
              'steps' => [
                { 'name' => 'CLAIMS_EVIDENCE', 'status' => 'IN_PROGRESS' },
                { 'name' => 'BENEFITS_GATEWAY_SERVICE', 'status' => 'NOT_STARTED' }
              ]
            },
            lighthouse526_document_upload
          )
          expect(status_updater.processing_timeout?).to eq(expected)
        end
      end
    end

    context 'when the document has been in progress for more than 24 hours' do
      it_behaves_like('processing timeout', 'IN_PROGRESS', (DateTime.new(1985, 10, 23).utc.to_i * 1000).to_i, true)
    end

    context 'when the document has been in progress for less than 24 hours' do
      it_behaves_like('processing timeout', 'IN_PROGRESS', (DateTime.new(1985, 10, 25, 20).utc.to_i * 1000).to_i, false)
    end
  end
end
