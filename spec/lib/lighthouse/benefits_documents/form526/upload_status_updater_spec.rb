# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/form526/upload_status_updater'

RSpec.describe BenefitsDocuments::Form526::UploadStatusUpdater do
  let(:lighthouse526_document_upload) { create(:lighthouse526_document_upload) }

  describe '#update_status' do
    let(:lighthouse526_document_upload) do
      create(:lighthouse526_document_upload, lighthouse_processing_started_at: nil)
    end

    context 'when the document is completed' do
      # Lighthouse returns datetimes as UNIX timestamps
      let(:unix_start_time) { 499152060 }
      let(:unix_end_time) { 499153000 }

      let(:completed_document_status) do
        {
          'status' => 'SUCCESS',
          'time' => {
            'startTime' => unix_start_time,
            'endTime' => unix_end_time
          },
          'steps' => [
            {
              'name' => 'CLAIMS_EVIDENCE',
              'status' => 'SUCCESS'
            },
            {
              'name' => 'BENEFITS_GATEWAY_SERVICE',
              'status' => 'SUCCESS'
            }
          ]
        }
      end

      it 'saves a lighthouse_processing_started_at time' do
        status_updater = described_class.new(completed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(
          lighthouse526_document_upload, :lighthouse_processing_started_at
        ).to(Time.at(unix_start_time).utc.to_datetime)
      end

      it 'saves a lighthouse_processing_ended_at time' do
        status_updater = described_class.new(completed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(
          lighthouse526_document_upload, :lighthouse_processing_ended_at
        ).to(Time.at(unix_end_time).utc.to_datetime)
      end

      it 'transitions the document to a complete state' do
        status_updater = described_class.new(completed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(lighthouse526_document_upload, :aasm_state)
          .from('pending').to('completed')
      end

      it 'saves the last_status_response' do
        status_updater = described_class.new(completed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(lighthouse526_document_upload, :last_status_response)
          .to(completed_document_status)
      end

      it 'logs the latest_status_response to the Rails logger' do
        Timecop.freeze(DateTime.new(1985, 10, 26)) do
          expect(Rails.logger).to receive(:info).with(
            'BenefitsDocuments::Form526::UploadStatusUpdater',
            status: 'SUCCESS',
            status_response: completed_document_status,
            updated_at: DateTime.new(1985, 10, 26)
          )

          status_updater = described_class.new(completed_document_status, lighthouse526_document_upload)
          status_updater.update_status
        end
      end

      it 'updates the status_last_polled_at time on the document' do
        Timecop.freeze(DateTime.new(1985, 10, 26)) do
          status_updater = described_class.new(completed_document_status, lighthouse526_document_upload)
          status_updater.update_status

          expect(lighthouse526_document_upload.status_last_polled_at).to eq(DateTime.new(1985, 10, 26))
        end
      end
    end

    context 'when the document has failed' do
      # Lighthouse returns datetimes as UNIX timestamps
      let(:unix_start_time) { 499152060 }
      let(:unix_end_time) { 499153000 }

      let(:failed_document_status) do
        {
          'status' => 'FAILED',
          'time' => {
            'startTime' => unix_start_time,
            'endTime' => unix_end_time
          },
          'steps' => [
            {
              'name' => 'CLAIMS_EVIDENCE',
              'status' => 'SUCCESS'
            },
            {
              'name' => 'BENEFITS_GATEWAY_SERVICE',
              'status' => 'FAILED'
            }
          ],
          'error' => {
            'detail' => 'BGS outage',
            'step' => 'BENEFITS_GATEWAY_SERVICE'
          }
        }
      end

      it 'saves a lighthouse_processing_started_at time' do
        status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(
          lighthouse526_document_upload, :lighthouse_processing_started_at
        ).to(Time.at(unix_start_time).utc.to_datetime)
      end

      it 'saves a lighthouse_processing_ended_at time' do
        status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(
          lighthouse526_document_upload, :lighthouse_processing_ended_at
        ).to(Time.at(unix_end_time).utc.to_datetime)
      end

      it 'transitions the document to a failed state' do
        status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(lighthouse526_document_upload, :aasm_state)
          .from('pending').to('failed')
      end

      it 'saves the last_status_response' do
        status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(lighthouse526_document_upload, :last_status_response)
          .to(failed_document_status)
      end

      it 'saves the error_message' do
        status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)

        expect { status_updater.update_status }.to change(lighthouse526_document_upload, :error_message)
          .to(
            {
              'detail' => 'BGS outage',
              'step' => 'BENEFITS_GATEWAY_SERVICE'
            }
          )
      end

      it 'logs the latest_status_response to the Rails logger' do
        Timecop.freeze(DateTime.new(1985, 10, 26)) do
          expect(Rails.logger).to receive(:info).with(
            'BenefitsDocuments::Form526::UploadStatusUpdater',
            status: 'FAILED',
            status_response: failed_document_status,
            updated_at: DateTime.new(1985, 10, 26)
          )

          status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)
          status_updater.update_status
        end
      end

      it 'updates the status_last_polled_at time on the document' do
        Timecop.freeze(DateTime.new(1985, 10, 26)) do
          status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)
          status_updater.update_status

          expect(lighthouse526_document_upload.status_last_polled_at).to eq(DateTime.new(1985, 10, 26))
        end
      end
    end

    context 'when the document is in progress' do
      let(:lighthouse526_new_document_upload) do
        create(
          :lighthouse526_document_upload,
          lighthouse_processing_started_at: nil,
          last_status_response: nil
        )
      end

      # Lighthouse returns datetimes as UNIX timestamps
      let(:unix_start_time) { 499152060 }

      let(:in_progress_document_status) do
        {
          'status' => 'IN_PROGRESS',
          'time' => {
            'startTime' => unix_start_time,
            'endTime' => nil
          },
          'steps' => [
            {
              'name' => 'CLAIMS_EVIDENCE',
              'status' => 'IN_PROGRESS'
            },
            {
              'name' => 'BENEFITS_GATEWAY_SERVICE',
              'status' => 'NOT_STARTED'
            }
          ]
        }
      end

      it 'does not change the state of the document' do
        status_updater = described_class.new(in_progress_document_status, lighthouse526_new_document_upload)

        expect { status_updater.update_status }.not_to change(
          lighthouse526_new_document_upload, :aasm_state
        )
      end

      it 'saves a lighthouse_processing_started_at time' do
        status_updater = described_class.new(in_progress_document_status, lighthouse526_new_document_upload)

        expect { status_updater.update_status }.to change(
          lighthouse526_new_document_upload, :lighthouse_processing_started_at
        ).to(Time.at(unix_start_time).utc.to_datetime)
      end

      it 'saves the last_status_response' do
        status_updater = described_class.new(in_progress_document_status, lighthouse526_new_document_upload)

        expect { status_updater.update_status }.to change(lighthouse526_new_document_upload, :last_status_response)
          .to(in_progress_document_status)
      end

      it 'logs the latest_status_response to the Rails logger' do
        Timecop.freeze(DateTime.new(1985, 10, 26)) do
          expect(Rails.logger).to receive(:info).with(
            'BenefitsDocuments::Form526::UploadStatusUpdater',
            status: 'IN_PROGRESS',
            status_response: in_progress_document_status,
            updated_at: DateTime.new(1985, 10, 26)
          )

          status_updater = described_class.new(in_progress_document_status, lighthouse526_document_upload)
          status_updater.update_status
        end
      end
    end
  end

  describe '#get_failure_step' do
    let(:failed_document_status) do
      {
        'status' => 'FAILED',
        'time' => {
          'startTime' => 499152060,
          'endTime' => 499153000
        },
        'steps' => [
          {
            'name' => 'CLAIMS_EVIDENCE',
            'status' => 'SUCCESS'
          },
          {
            'name' => 'BENEFITS_GATEWAY_SERVICE',
            'status' => 'FAILED'
          }
        ],
        'error' => {
          'detail' => 'BGS outage',
          'step' => 'BENEFITS_GATEWAY_SERVICE'
        }
      }
    end

    it 'returns the name of the step Lighthouse said failed' do
      status_updater = described_class.new(failed_document_status, lighthouse526_document_upload)
      expect(status_updater.get_failure_step).to eq('BENEFITS_GATEWAY_SERVICE')
    end
  end

  describe '#processing_timeout?' do
    context 'when the document has been in progress for more than 24 hours' do
      it 'returns true' do
        Timecop.freeze(DateTime.new(1985, 10, 26).utc) do
          # Lighthouse returns datetimes as UNIX timestamps
          unix_start_time = DateTime.new(1985, 10, 23).to_time.to_i

          delayed_document_status = {
            'status' => 'IN_PROGRESS',
            'time' => {
              'startTime' => unix_start_time,
              'endTime' => nil
            },
            'steps' => [
              {
                'name' => 'CLAIMS_EVIDENCE',
                'status' => 'IN_PROGRESS'
              },
              {
                'name' => 'BENEFITS_GATEWAY_SERVICE',
                'status' => 'NOT_STARTED'
              }
            ]
          }

          status_updater = described_class.new(delayed_document_status, lighthouse526_document_upload)
          expect(status_updater.processing_timeout?).to eq(true)
        end
      end
    end

    context 'when the document has been in progress for less than 24 hours' do
      it 'returns false' do
        Timecop.freeze(DateTime.new(1985, 10, 26).utc) do
          # Lighthouse returns datetimes as UNIX timestamps
          unix_start_time = DateTime.new(1985, 10, 25, 20).utc.to_time.to_i

          in_progress_document_status = {
            'status' => 'IN_PROGRESS',
            'time' => {
              'startTime' => unix_start_time,
              'endTime' => nil
            },
            'steps' => [
              {
                'name' => 'CLAIMS_EVIDENCE',
                'status' => 'IN_PROGRESS'
              },
              {
                'name' => 'BENEFITS_GATEWAY_SERVICE',
                'status' => 'NOT_STARTED'
              }
            ]
          }

          status_updater = described_class.new(in_progress_document_status, lighthouse526_document_upload)
          expect(status_updater.processing_timeout?).to eq(false)
        end
      end
    end
  end
end
