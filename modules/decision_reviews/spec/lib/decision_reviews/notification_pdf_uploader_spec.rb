# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require 'decision_reviews/notification_pdf_uploader'
require './modules/decision_reviews/lib/decision_reviews/pdf_template_stamper'
require './modules/decision_reviews/lib/decision_reviews/v1/service'
require './modules/decision_reviews/lib/decision_reviews/notification_email_to_pdf_service'

RSpec.describe DecisionReviews::NotificationPdfUploader do
  let(:user) { create(:user, :loa3, ssn: '212222112') }
  let(:submitted_appeal_uuid) { SecureRandom.uuid }
  let(:notification_id) { SecureRandom.uuid }
  let(:vbms_file_uuid) { "#{SecureRandom.uuid}-vbms" }

  let(:appeal_submission) do
    create(:appeal_submission_module,
           user_uuid: user.uuid,
           user_account: user.user_account,
           submitted_appeal_uuid:,
           type_of_appeal: 'SC')
  end

  let(:audit_log) do
    DecisionReviewNotificationAuditLog.create!(
      notification_id:,
      reference: "SC-form-#{submitted_appeal_uuid}",
      status: 'delivered',
      payload: {
        'to' => 'veteran@example.com',
        'sent_at' => '2025-11-01T10:00:00Z'
      }.to_json
    )
  end

  let(:pdf_path) { 'tmp/pdfs/test_notification.pdf' }
  let(:folder_identifier) { "VETERAN:ICN:#{user.icn}" }

  let(:claims_evidence_service) { instance_double(ClaimsEvidenceApi::Service::Files) }
  let(:upload_response) do
    double('Response', body: { 'uuid' => vbms_file_uuid })
  end

  before do
    allow(AppealSubmission).to receive(:find_by!).with(submitted_appeal_uuid:).and_return(appeal_submission)
    allow(ClaimsEvidenceApi::Service::Files).to receive(:new).and_return(claims_evidence_service)
    allow(claims_evidence_service).to receive(:folder_identifier=)
    allow(File).to receive(:delete)
    allow(File).to receive(:exist?).and_return(true)
  end

  describe '#initialize' do
    it 'initializes with audit_log' do
      uploader = described_class.new(audit_log)
      expect(uploader.audit_log).to eq(audit_log)
      expect(uploader.appeal_submission).to eq(appeal_submission)
    end

    context 'when AppealSubmission not found for form reference' do
      before do
        allow(AppealSubmission).to receive(:find_by!)
          .with(submitted_appeal_uuid:)
          .and_raise(ActiveRecord::RecordNotFound)
      end

      it 'raises UploadError' do
        expect do
          described_class.new(audit_log)
        end.to raise_error(DecisionReviews::NotificationPdfUploader::UploadError, /AppealSubmission not found/)
      end
    end

    context 'with evidence reference format' do
      let(:lighthouse_upload_id) { '12345' }
      let(:appeal_submission_upload) { instance_double(AppealSubmissionUpload, appeal_submission:) }

      let(:audit_log) do
        DecisionReviewNotificationAuditLog.create!(
          notification_id:,
          reference: "SC-evidence-#{lighthouse_upload_id}",
          status: 'delivered',
          payload: { 'to' => 'veteran@example.com', 'sent_at' => '2025-11-01T10:00:00Z' }.to_json
        )
      end

      before do
        allow(AppealSubmissionUpload).to receive(:find_by!)
          .with(lighthouse_upload_id:)
          .and_return(appeal_submission_upload)
      end

      it 'finds appeal submission via AppealSubmissionUpload' do
        uploader = described_class.new(audit_log)
        expect(uploader.appeal_submission).to eq(appeal_submission)
      end
    end

    context 'with secondary_form reference format' do
      let(:guid) { SecureRandom.uuid }
      let(:secondary_appeal_form) { instance_double(SecondaryAppealForm, appeal_submission:) }

      let(:audit_log) do
        DecisionReviewNotificationAuditLog.create!(
          notification_id:,
          reference: "SC-secondary_form-#{guid}",
          status: 'delivered',
          payload: { 'to' => 'veteran@example.com', 'sent_at' => '2025-11-01T10:00:00Z' }.to_json
        )
      end

      before do
        allow(SecondaryAppealForm).to receive(:find_by!)
          .with(guid:)
          .and_return(secondary_appeal_form)
      end

      it 'finds appeal submission via SecondaryAppealForm' do
        uploader = described_class.new(audit_log)
        expect(uploader.appeal_submission).to eq(appeal_submission)
      end
    end
  end

  describe '#upload_to_vbms' do
    let(:pdf_service) { instance_double(DecisionReviews::NotificationEmailToPdfService) }

    before do
      allow(DecisionReviews::NotificationEmailToPdfService).to receive(:new).and_return(pdf_service)
      allow(pdf_service).to receive(:generate_pdf).and_return(pdf_path)
      allow(claims_evidence_service).to receive(:upload).and_return(upload_response)
    end

    it 'generates PDF and uploads to VBMS' do
      uploader = described_class.new(audit_log)
      file_uuid = uploader.upload_to_vbms

      expect(file_uuid).to eq(vbms_file_uuid)
      expect(DecisionReviews::NotificationEmailToPdfService).to have_received(:new)
        .with(audit_log, appeal_submission:)
      expect(pdf_service).to have_received(:generate_pdf)
    end

    it 'sets correct folder identifier' do
      uploader = described_class.new(audit_log)
      uploader.upload_to_vbms

      expect(claims_evidence_service).to have_received(:folder_identifier=).with(folder_identifier)
    end

    it 'uploads with correct provider data' do
      uploader = described_class.new(audit_log)
      uploader.upload_to_vbms

      expect(claims_evidence_service).to have_received(:upload).with(
        pdf_path,
        provider_data: {
          contentSource: ClaimsEvidenceApi::CONTENT_SOURCE,
          dateVaReceivedDocument: kind_of(String),
          documentTypeId: described_class::NOTIFICATION_EMAIL_DOCTYPE
        }
      )
    end

    it 'updates audit log with success' do
      uploader = described_class.new(audit_log)
      uploader.upload_to_vbms

      audit_log.reload
      expect(audit_log.pdf_uploaded_at).not_to be_nil
      expect(audit_log.vbms_file_uuid).to eq(vbms_file_uuid)
      expect(audit_log.pdf_upload_error).to be_nil
    end

    it 'logs successful upload' do
      allow(Rails.logger).to receive(:info)

      uploader = described_class.new(audit_log)
      uploader.upload_to_vbms

      expect(Rails.logger).to have_received(:info).with(
        'DecisionReviews::NotificationPdfUploader uploaded PDF',
        hash_including(
          notification_id:,
          file_uuid: vbms_file_uuid,
          appeal_type: 'SC'
        )
      )
    end

    it 'cleans up PDF file after upload' do
      uploader = described_class.new(audit_log)
      uploader.upload_to_vbms

      expect(File).to have_received(:delete).with(pdf_path)
    end

    context 'when upload fails' do
      let(:error_message) { 'VBMS API error' }

      before do
        allow(claims_evidence_service).to receive(:upload)
          .and_raise(Common::Client::Errors::ClientError.new(error_message, 503))
      end

      it 'updates audit log with failure' do
        uploader = described_class.new(audit_log)

        expect do
          uploader.upload_to_vbms
        end.to raise_error(DecisionReviews::NotificationPdfUploader::UploadError)

        audit_log.reload
        expect(audit_log.pdf_uploaded_at).to be_nil
        expect(audit_log.vbms_file_uuid).to be_nil
        expect(audit_log.pdf_upload_attempt_count).to eq(1)
        expect(audit_log.pdf_upload_error).to include(error_message)
      end

      it 'raises UploadError with message' do
        uploader = described_class.new(audit_log)

        expect do
          uploader.upload_to_vbms
        end.to raise_error(
          DecisionReviews::NotificationPdfUploader::UploadError,
          /Failed to upload notification PDF.*#{error_message}/
        )
      end

      it 'still cleans up PDF file' do
        uploader = described_class.new(audit_log)

        expect do
          uploader.upload_to_vbms
        end.to raise_error(DecisionReviews::NotificationPdfUploader::UploadError)

        expect(File).to have_received(:delete).with(pdf_path)
      end

      it 'increments attempt count on each failure' do
        uploader = described_class.new(audit_log)

        # First attempt
        expect { uploader.upload_to_vbms }.to raise_error(DecisionReviews::NotificationPdfUploader::UploadError)
        audit_log.reload
        expect(audit_log.pdf_upload_attempt_count).to eq(1)

        # Second attempt
        expect { uploader.upload_to_vbms }.to raise_error(DecisionReviews::NotificationPdfUploader::UploadError)
        audit_log.reload
        expect(audit_log.pdf_upload_attempt_count).to eq(2)
      end
    end

    context 'when PDF generation fails' do
      before do
        allow(pdf_service).to receive(:generate_pdf).and_raise(StandardError, 'PDF generation failed')
      end

      it 'updates audit log and raises error' do
        uploader = described_class.new(audit_log)

        expect do
          uploader.upload_to_vbms
        end.to raise_error(DecisionReviews::NotificationPdfUploader::UploadError, /PDF generation failed/)

        audit_log.reload
        expect(audit_log.pdf_upload_attempt_count).to eq(1)
        expect(audit_log.pdf_upload_error).to include('PDF generation failed')
      end
    end

    context 'when PDF file does not exist during cleanup' do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'does not attempt to delete file' do
        uploader = described_class.new(audit_log)
        uploader.upload_to_vbms

        expect(File).not_to have_received(:delete)
      end
    end
  end

  describe '#build_folder_identifier' do
    it 'generates correct folder identifier from ICN' do
      uploader = described_class.new(audit_log)
      folder_id = uploader.send(:build_folder_identifier)

      expect(folder_id).to eq("VETERAN:ICN:#{user.icn}")
    end
  end

  describe '#build_provider_data' do
    it 'includes correct metadata' do
      uploader = described_class.new(audit_log)
      provider_data = uploader.send(:build_provider_data)

      expect(provider_data).to include(
        contentSource: ClaimsEvidenceApi::CONTENT_SOURCE,
        documentTypeId: described_class::NOTIFICATION_EMAIL_DOCTYPE
      )
      expect(provider_data[:dateVaReceivedDocument]).to match(/\d{4}-\d{2}-\d{2}/)
    end
  end

  describe '#format_date' do
    it 'formats datetime correctly' do
      uploader = described_class.new(audit_log)
      datetime = Time.zone.parse('2025-11-17 15:30:00')
      formatted = uploader.send(:format_date, datetime)

      expect(formatted).to match(/\d{4}-\d{2}-\d{2}/)
    end
  end

  describe 'with different appeal types' do
    %w[SC HLR NOD].each do |appeal_type|
      context "with #{appeal_type} appeal" do
        let(:appeal_submission) do
          create(:appeal_submission_module,
                 user_uuid: user.uuid,
                 user_account: user.user_account,
                 submitted_appeal_uuid:,
                 type_of_appeal: appeal_type)
        end
        let(:pdf_service) { instance_double(DecisionReviews::NotificationEmailToPdfService) }

        let(:audit_log) do
          DecisionReviewNotificationAuditLog.create!(
            notification_id:,
            reference: "#{appeal_type}-form-#{submitted_appeal_uuid}",
            status: 'delivered',
            payload: { 'to' => 'veteran@example.com', 'sent_at' => '2025-11-01T10:00:00Z' }.to_json
          )
        end

        before do
          allow(pdf_service).to receive(:generate_pdf).and_return(pdf_path)
          allow(claims_evidence_service).to receive(:upload).and_return(upload_response)
          allow(DecisionReviews::NotificationEmailToPdfService).to receive(:new).and_return(pdf_service)
        end

        it "successfully uploads #{appeal_type} notification PDF" do
          uploader = described_class.new(audit_log)
          file_uuid = uploader.upload_to_vbms

          expect(file_uuid).to eq(vbms_file_uuid)
        end
      end
    end
  end

  describe 'NOTIFICATION_EMAIL_DOCTYPE constant' do
    it 'is set to Email Correspondence doctype' do
      expect(described_class::NOTIFICATION_EMAIL_DOCTYPE).to eq(40)
    end
  end
end
