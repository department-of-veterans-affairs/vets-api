# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/upload_status_updater'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

RSpec.describe BenefitsDocuments::UploadStatusUpdater do
  let(:lighthouse_document_upload) do
    create(:bd_evidence_submission_pending,
           job_class: 'BenefitsDocuments::Service',
           claim_id: '1234')
  end
  let(:lighthouse_document_upload_timeout) { create(:bd_evidence_submission_timeout) }
  let(:past_date_time) { DateTime.new(1985, 10, 26) }
  let(:current_date_time) { DateTime.current }
  let(:issue_instant) { Time.now.to_i }

  describe '#update_status' do
    shared_examples 'status updater' do |status, error_message = nil|
      let(:document_status_response) do
        {
          'status' => status,
          'error' => error_message
        }.compact
      end
      let(:status_updater) { described_class.new(document_status_response, lighthouse_document_upload) }
      let(:date) do
        BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
      end
      let(:updated_template_metadata) do
        { 'personalisation' => {
          'first_name' => 'test',
          'document_type' => 'Birth Certificate',
          'file_name' => 'testfile.txt',
          'obfuscated_file_name' => 'tesXXile.txt',
          'date_submitted' => date,
          'date_failed' => date
        } }.to_json
      end

      it 'logs the document_status_response to the Rails logger when a status change occurred' do
        Timecop.freeze(past_date_time) do
          expect(lighthouse_document_upload.upload_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
          expect(status).not_to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
          expect(Rails.logger).to receive(:info).with(
            'LH - Status changed',
            old_status: lighthouse_document_upload.upload_status,
            status:,
            status_response: document_status_response,
            evidence_submission_id: lighthouse_document_upload.id,
            claim_id: lighthouse_document_upload.claim_id
          )
          expect(Rails.logger).to receive(:info).with(
            'BenefitsDocuments::UploadStatusUpdater',
            status:,
            status_response: document_status_response,
            updated_at: past_date_time,
            evidence_submission_id: lighthouse_document_upload.id,
            claim_id: lighthouse_document_upload.claim_id
          )

          status_updater.update_status
        end
        Timecop.unfreeze
      end

      if error_message
        context "when there's an error" do
          it 'saves the error_message' do
            Timecop.freeze(current_date_time) do
              expect { status_updater.update_status }.to change(lighthouse_document_upload, :error_message)
                .to(error_message.to_s)
            end
            Timecop.unfreeze
          end

          it 'updates status, failed_date, acknowledgement_date and template_metadata' do
            Timecop.freeze(current_date_time) do
              expect { status_updater.update_status }
                .to change(lighthouse_document_upload, :acknowledgement_date)
                .from(nil)
                .to(be_within(1.second).of((current_date_time + 30.days)))
                .and change(lighthouse_document_upload, :failed_date)
                .from(nil)
                .to(be_within(1.second).of(current_date_time))
                .and change(lighthouse_document_upload, :upload_status)
                .from(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
                .to(BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
                .and change(lighthouse_document_upload, :template_metadata)
                .from(lighthouse_document_upload.template_metadata)
                .to(updated_template_metadata)
            end
            Timecop.unfreeze
          end
        end
      else # testing success status
        context 'when completed successfully' do
          it 'updates status, and delete_date' do
            allow(Rails.logger).to receive(:info)
            Timecop.freeze(current_date_time) do
              expect { status_updater.update_status }
                .to change(lighthouse_document_upload, :delete_date)
                .from(nil)
                .to(be_within(1.second).of((current_date_time + 60.days)))
                .and change(lighthouse_document_upload, :upload_status)
                .from(BenefitsDocuments::Constants::UPLOAD_STATUS[:PENDING])
                .to(BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS])
            end
            Timecop.unfreeze
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
