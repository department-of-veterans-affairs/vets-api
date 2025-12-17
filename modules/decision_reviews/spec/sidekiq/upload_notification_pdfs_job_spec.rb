# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/sidekiq_helper'
require './modules/decision_reviews/lib/decision_reviews/pdf_template_stamper'
require './modules/decision_reviews/lib/decision_reviews/v1/service'
require './modules/decision_reviews/lib/decision_reviews/notification_email_to_pdf_service'

RSpec.describe DecisionReviews::UploadNotificationPdfsJob, type: :job do
  subject { described_class }

  let(:user) { create(:user, :loa3, ssn: '212222112') }
  let(:submitted_appeal_uuid1) { SecureRandom.uuid }
  let(:submitted_appeal_uuid2) { SecureRandom.uuid }
  let(:notification_id1) { SecureRandom.uuid }
  let(:notification_id2) { SecureRandom.uuid }
  let(:vbms_file_uuid1) { "#{SecureRandom.uuid}-vbms-1" }
  let(:vbms_file_uuid2) { "#{SecureRandom.uuid}-vbms-2" }

  let(:audit_log1) do
    DecisionReviewNotificationAuditLog.create!(
      notification_id: notification_id1,
      reference: "SC-form-#{submitted_appeal_uuid1}",
      status: 'delivered',
      payload: { 'completed_at' => '2025-11-01T10:00:00Z' }.to_json
    )
  end

  let(:audit_log2) do
    DecisionReviewNotificationAuditLog.create!(
      notification_id: notification_id2,
      reference: "HLR-form-#{submitted_appeal_uuid2}",
      status: 'delivered',
      payload: { 'completed_at' => '2025-11-01T11:00:00Z' }.to_json
    )
  end

  let(:already_uploaded_log) do
    DecisionReviewNotificationAuditLog.create!(
      notification_id: SecureRandom.uuid,
      reference: "NOD-form-#{SecureRandom.uuid}",
      status: 'delivered',
      payload: { 'completed_at' => '2025-11-01T09:00:00Z' }.to_json,
      pdf_uploaded_at: 1.day.ago,
      vbms_file_uuid: 'already-uploaded-uuid'
    )
  end

  let(:max_retries_log) do
    DecisionReviewNotificationAuditLog.create!(
      notification_id: SecureRandom.uuid,
      reference: "SC-form-#{SecureRandom.uuid}",
      status: 'delivered',
      payload: { 'completed_at' => '2025-11-01T08:00:00Z' }.to_json,
      pdf_upload_attempt_count: 3,
      pdf_upload_error: 'Max retries reached'
    )
  end

  let(:temporary_failure_log) do
    DecisionReviewNotificationAuditLog.create!(
      notification_id: SecureRandom.uuid,
      reference: "SC-form-#{SecureRandom.uuid}",
      status: 'temporary-failure',
      payload: { 'completed_at' => '2025-11-01T12:00:00Z' }.to_json
    )
  end

  let(:permanent_failure_log) do
    DecisionReviewNotificationAuditLog.create!(
      notification_id: SecureRandom.uuid,
      reference: "NOD-form-#{SecureRandom.uuid}",
      status: 'permanent-failure',
      payload: { 'completed_at' => '2025-11-01T13:00:00Z' }.to_json
    )
  end

  let(:uploader1) { instance_double(DecisionReviews::NotificationPdfUploader) }
  let(:uploader2) { instance_double(DecisionReviews::NotificationPdfUploader) }
  let(:uploader_permanent_failure) { instance_double(DecisionReviews::NotificationPdfUploader) }

  around do |example|
    # Freeze time to after the CUTOFF_DATE (Dec 12, 2025) so test fixtures are created after cutoff
    Timecop.freeze(Date.new(2025, 12, 25)) do
      Sidekiq::Testing.inline!(&example)
    end
  end

  before do
    # Clean up any pre-existing records to avoid database pollution between tests
    DecisionReviewNotificationAuditLog.delete_all

    allow(Flipper).to receive(:enabled?).with(:decision_review_upload_notification_pdfs_enabled).and_return(true)
    allow(StatsD).to receive(:increment)
    allow(StatsD).to receive(:gauge)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)

    allow(DecisionReviews::NotificationPdfUploader).to receive(:new).with(audit_log1).and_return(uploader1)
    allow(DecisionReviews::NotificationPdfUploader).to receive(:new).with(audit_log2).and_return(uploader2)
    allow(DecisionReviews::NotificationPdfUploader).to receive(:new).with(permanent_failure_log)
                                                                    .and_return(uploader_permanent_failure)
    allow(uploader1).to receive(:upload_to_vbms).and_return(vbms_file_uuid1)
    allow(uploader2).to receive(:upload_to_vbms).and_return(vbms_file_uuid2)
    allow(uploader_permanent_failure).to receive(:upload_to_vbms).and_return("#{SecureRandom.uuid}-vbms-perm")
  end

  describe '#perform' do
    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:decision_review_upload_notification_pdfs_enabled).and_return(false)
      end

      it 'does not process any uploads' do
        subject.new.perform

        expect(DecisionReviews::NotificationPdfUploader).not_to have_received(:new)
        expect(StatsD).not_to have_received(:increment)
      end
    end

    context 'when feature flag is enabled' do
      it 'increments started metric' do
        subject.new.perform

        expect(StatsD).to have_received(:increment)
          .with('worker.decision_reviews.upload_notification_email_pdfs.started')
      end

      it 'fetches only pending uploads' do
        subject.new.perform

        # Should create uploaders for the 2 pending logs
        expect(DecisionReviews::NotificationPdfUploader).to have_received(:new).with(audit_log1)
        expect(DecisionReviews::NotificationPdfUploader).to have_received(:new).with(audit_log2)

        # Should not create uploaders for already uploaded or max retries logs
        expect(DecisionReviews::NotificationPdfUploader).not_to have_received(:new)
          .with(already_uploaded_log)
        expect(DecisionReviews::NotificationPdfUploader).not_to have_received(:new)
          .with(max_retries_log)
      end

      it 'uploads all pending PDFs' do
        subject.new.perform

        expect(uploader1).to have_received(:upload_to_vbms)
        expect(uploader2).to have_received(:upload_to_vbms)
      end

      it 'increments success metric for each upload' do
        subject.new.perform

        expect(StatsD).to have_received(:increment)
          .with('worker.decision_reviews.upload_notification_email_pdfs.upload_success').exactly(3).times
      end

      it 'logs successful uploads' do
        subject.new.perform

        expect(Rails.logger).to have_received(:info).with(
          'DecisionReviews::UploadNotificationPdfsJob uploaded PDF',
          hash_including(notification_id: notification_id1, file_uuid: vbms_file_uuid1)
        )
        expect(Rails.logger).to have_received(:info).with(
          'DecisionReviews::UploadNotificationPdfsJob uploaded PDF',
          hash_including(notification_id: notification_id2, file_uuid: vbms_file_uuid2)
        )
      end

      it 'logs batch results with gauges' do
        subject.new.perform

        expect(StatsD).to have_received(:gauge)
          .with('worker.decision_reviews.upload_notification_email_pdfs.total_count', 3)
        expect(StatsD).to have_received(:gauge)
          .with('worker.decision_reviews.upload_notification_email_pdfs.success_count', 3)
        expect(StatsD).to have_received(:gauge)
          .with('worker.decision_reviews.upload_notification_email_pdfs.failure_count', 0)
      end

      it 'logs completion summary' do
        subject.new.perform

        expect(Rails.logger).to have_received(:info).with(
          'DecisionReviews::UploadNotificationPdfsJob complete',
          hash_including(total: 3, success: 3, failures: 0)
        )
      end

      context 'when no pending uploads exist' do
        before do
          # Mark all final status logs as uploaded
          audit_log1.update!(pdf_uploaded_at: Time.current, vbms_file_uuid: 'uuid1')
          audit_log2.update!(pdf_uploaded_at: Time.current, vbms_file_uuid: 'uuid2')
          permanent_failure_log.update!(pdf_uploaded_at: Time.current, vbms_file_uuid: 'uuid3')
        end

        it 'increments no_pending_uploads metric' do
          subject.new.perform

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_reviews.upload_notification_email_pdfs.no_pending_uploads')
        end

        it 'does not process any uploads' do
          subject.new.perform

          expect(DecisionReviews::NotificationPdfUploader).not_to have_received(:new)
        end

        it 'does not log results' do
          subject.new.perform

          expect(Rails.logger).not_to have_received(:info)
            .with('DecisionReviews::UploadNotificationPdfsJob complete', anything)
        end
      end

      context 'when records exist before the cutoff date' do
        let!(:old_audit_log) do
          DecisionReviewNotificationAuditLog.create!(
            notification_id: SecureRandom.uuid,
            reference: "SC-form-#{SecureRandom.uuid}",
            status: 'delivered',
            payload: { 'completed_at' => '2025-11-01T10:00:00Z' }.to_json,
            created_at: Date.new(2025, 12, 1) # Before CUTOFF_DATE
          )
        end

        it 'does not process records created before cutoff date' do
          subject.new.perform

          expect(DecisionReviews::NotificationPdfUploader).not_to have_received(:new).with(old_audit_log)
        end

        it 'still processes records created on or after cutoff date' do
          subject.new.perform

          expect(DecisionReviews::NotificationPdfUploader).to have_received(:new).with(audit_log1)
          expect(DecisionReviews::NotificationPdfUploader).to have_received(:new).with(audit_log2)
        end
      end

      context 'when an upload fails' do
        let(:error_message) { 'VBMS upload failed' }

        before do
          allow(uploader1).to receive(:upload_to_vbms)
            .and_raise(DecisionReviews::NotificationPdfUploader::UploadError, error_message)
        end

        it 'continues processing other uploads' do
          subject.new.perform

          expect(uploader2).to have_received(:upload_to_vbms)
        end

        it 'increments failure metric' do
          subject.new.perform

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_reviews.upload_notification_email_pdfs.upload_failure')
        end

        it 'logs upload failure' do
          subject.new.perform

          expect(Rails.logger).to have_received(:error).with(
            'DecisionReviews::UploadNotificationPdfsJob upload failed',
            hash_including(
              notification_id: notification_id1,
              error: error_message
            )
          )
        end

        it 'logs batch results with correct counts' do
          subject.new.perform

          expect(StatsD).to have_received(:gauge)
            .with('worker.decision_reviews.upload_notification_email_pdfs.total_count', 3)
          expect(StatsD).to have_received(:gauge)
            .with('worker.decision_reviews.upload_notification_email_pdfs.success_count', 2)
          expect(StatsD).to have_received(:gauge)
            .with('worker.decision_reviews.upload_notification_email_pdfs.failure_count', 1)
        end

        it 'logs completion with failure count' do
          subject.new.perform

          expect(Rails.logger).to have_received(:info).with(
            'DecisionReviews::UploadNotificationPdfsJob complete',
            hash_including(total: 3, success: 2, failures: 1)
          )
        end
      end

      context 'when job itself raises an error' do
        before do
          allow(DecisionReviewNotificationAuditLog).to receive(:where)
            .and_raise(StandardError, 'Database connection error')
        end

        it 'increments error metric' do
          expect { subject.new.perform }.to raise_error(StandardError, 'Database connection error')

          expect(StatsD).to have_received(:increment)
            .with('worker.decision_reviews.upload_notification_email_pdfs.error')
        end

        it 'logs the error' do
          expect { subject.new.perform }.to raise_error(StandardError)

          expect(Rails.logger).to have_received(:error).with(
            'DecisionReviews::UploadNotificationPdfsJob error',
            hash_including(error: 'Database connection error')
          )
        end

        it 're-raises the error' do
          expect { subject.new.perform }.to raise_error(StandardError, 'Database connection error')
        end
      end
    end
  end

  describe '#fetch_pending_uploads' do
    it 'only fetches logs without pdf_uploaded_at' do
      job = subject.new
      pending = job.send(:fetch_pending_uploads)

      expect(pending).to include(audit_log1, audit_log2)
      expect(pending).not_to include(already_uploaded_log)
    end

    it 'only fetches logs with attempt count less than max' do
      job = subject.new
      pending = job.send(:fetch_pending_uploads)

      expect(pending).to include(audit_log1, audit_log2)
      expect(pending).not_to include(max_retries_log)
    end

    it 'only fetches logs with final statuses (delivered or permanent-failure)' do
      job = subject.new
      pending = job.send(:fetch_pending_uploads)

      expect(pending).to include(audit_log1, audit_log2)  # delivered
      expect(pending).to include(permanent_failure_log)   # permanent-failure
      expect(pending).not_to include(temporary_failure_log) # temporary-failure excluded
    end

    it 'excludes temporary-failure status records' do
      job = subject.new
      pending = job.send(:fetch_pending_uploads)

      expect(pending.pluck(:status)).not_to include('temporary-failure')
    end

    it 'includes permanent-failure status records' do
      job = subject.new
      pending = job.send(:fetch_pending_uploads)

      expect(pending).to include(permanent_failure_log)
    end
  end
end
