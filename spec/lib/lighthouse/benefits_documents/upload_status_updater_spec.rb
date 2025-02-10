# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/upload_status_updater'
require 'lighthouse/benefits_documents/constants'

RSpec.describe BenefitsDocuments::UploadStatusUpdater do
  let(:lighthouse_document_upload) { create(:bd_evidence_submission_pending) }
  let(:lighthouse_document_upload_timeout) { create(:bd_evidence_submission_timeout) }
  let(:past_date_time) { DateTime.new(1985, 10, 26) }
  let(:current_date_time) { DateTime.now.utc }

  describe '#update_status' do
    shared_examples 'status updater' do |status, error_message = nil|
      let(:document_status_response) do
        {
          'status' => status,
          'error' => error_message
        }.compact
      end
      let(:status_updater) { described_class.new(document_status_response, lighthouse_document_upload) }

      it 'logs the document_status_response to the Rails logger' do
        Timecop.freeze(past_date_time) do
          expect(Rails.logger).to receive(:info).with(
            'BenefitsDocuments::UploadStatusUpdater',
            status:,
            status_response: document_status_response,
            updated_at: past_date_time
          )

          status_updater.update_status
        end
      end

      if error_message
        context "when there's an error" do
          it 'saves the error_message' do
            Timecop.freeze(current_date_time) do
              expect { status_updater.update_status }.to change(lighthouse_document_upload, :error_message)
                .to(error_message.to_s)
            end
          end

          it 'updates status, failed_date, and acknowledgement_date' do
            Timecop.freeze(current_date_time) do
              expect { status_updater.update_status }
                .to change(lighthouse_document_upload, :acknowledgement_date)
                .from(nil)
                .to(be_within(1.second).of((current_date_time + 30.days).utc))
                .and change(lighthouse_document_upload, :failed_date)
                .from(nil)
                .to(be_within(1.second).of(current_date_time.utc))
                .and change(lighthouse_document_upload, :upload_status)
                .from(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
                .to(BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
            end
          end
        end
      else # testing success status
        context 'when completed successfully' do
          it 'updates status, and delete_date' do
            Timecop.freeze(current_date_time) do
              expect { status_updater.update_status }
                .to change(lighthouse_document_upload, :delete_date)
                .from(nil)
                .to(be_within(1.second).of((current_date_time + 60.days).utc))
                .and change(lighthouse_document_upload, :upload_status)
                .from(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
                .to(BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS])
            end
          end
        end
      end
    end

    context 'when the document is completed' do
      it_behaves_like('status updater', BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS])
    end

    context 'when the document has failed' do
      error_message = { 'detail' => 'BGS outage', 'step' => 'BENEFITS_GATEWAY_SERVICE' }

      it_behaves_like('status updater', BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED], error_message)
    end
  end
end
