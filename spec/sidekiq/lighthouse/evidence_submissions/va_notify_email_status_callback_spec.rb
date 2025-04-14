# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/constants'

describe Lighthouse::EvidenceSubmissions::VANotifyEmailStatusCallback do
  describe '#call' do
    context 'notification callback' do
      let(:notification_type) { :error }
      let(:callback_metadata) { { notification_type: } }

      context 'permanent-failure' do
        let!(:notification_record) do
          build(:notification, status: 'permanent-failure', notification_id: SecureRandom.uuid, callback_metadata:)
        end

        let!(:notification_record_evss) do
          build(:notification, status: 'permanent-failure', notification_id: SecureRandom.uuid, callback_metadata:)
        end

        let!(:evidence_submission) do
          create(:bd_evidence_submission_failed_va_notify_email_enqueued,
                 va_notify_id: notification_record.notification_id)
        end

        let!(:evidence_submission_evss) do
          create(:bd_evss_evidence_submission_failed_va_notify_email_enqueued,
                 va_notify_id: notification_record_evss.notification_id)
        end

        it 'logs error and increments StatsD for Lighthouse' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          es = EvidenceSubmission.find_by(va_notify_id: notification_record.notification_id)
          expect(Rails.logger).to have_received(:error).with(
            'Lighthouse::EvidenceSubmissions::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type,
              request_id: es.request_id,
              job_class: es.job_class }
          )
          expect(StatsD).to have_received(:increment)
            .with('silent_failure',
                  tags: ['service:claim-status', 'function: Lighthouse - VA Notify evidence upload failure email'])
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.permanent_failure')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.cst_document_uploads.va_notify.notifications.permanent_failure')
        end

        it 'logs error and increments StatsD for EVSS' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record_evss)
          es = EvidenceSubmission.find_by(va_notify_id: notification_record_evss.notification_id)
          expect(Rails.logger).to have_received(:error).with(
            'Lighthouse::EvidenceSubmissions::VANotifyEmailStatusCallback',
            { notification_id: notification_record_evss.notification_id,
              source_location: notification_record_evss.source_location,
              status: notification_record_evss.status,
              status_reason: notification_record_evss.status_reason,
              notification_type: notification_record_evss.notification_type,
              request_id: es.request_id,
              job_class: es.job_class }
          )
          expect(StatsD).to have_received(:increment)
            .with('silent_failure',
                  tags: ['service:claim-status', 'function: EVSS - VA Notify evidence upload failure email'])
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.permanent_failure')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.cst_document_uploads.va_notify.notifications.permanent_failure')
        end

        it 'updates va_notify_status' do
          described_class.call(notification_record)
          es = EvidenceSubmission.find_by(va_notify_id: notification_record.notification_id)
          expect(es.va_notify_status).to eq(BenefitsDocuments::Constants::VANOTIFY_STATUS[:FAILED])
        end
      end

      context 'delivered' do
        let!(:notification_record) do
          build(:notification, status: 'delivered', notification_id: SecureRandom.uuid)
        end

        let!(:notification_record_evss) do
          build(:notification, status: 'delivered', notification_id: SecureRandom.uuid)
        end

        let!(:evidence_submission) do
          create(:bd_evidence_submission_failed_va_notify_email_enqueued,
                 va_notify_id: notification_record.notification_id)
        end

        let!(:evidence_submission_evss) do
          create(:bd_evss_evidence_submission_failed_va_notify_email_enqueued,
                 va_notify_id: notification_record_evss.notification_id)
        end

        it 'logs success and increments StatsD for Lighthouse' do
          allow(StatsD).to receive(:increment)
          described_class.call(notification_record)
          expect(StatsD).to have_received(:increment)
            .with('silent_failure_avoided',
                  tags: ['service:claim-status',
                         'function: Lighthouse - VA Notify evidence upload failure email'])
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.delivered')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.cst_document_uploads.va_notify.notifications.delivered')
        end

        it 'logs success and increments StatsD for EVSS' do
          allow(StatsD).to receive(:increment)
          described_class.call(notification_record_evss)
          expect(StatsD).to have_received(:increment)
            .with('silent_failure_avoided',
                  tags: ['service:claim-status',
                         'function: EVSS - VA Notify evidence upload failure email'])
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.delivered')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.cst_document_uploads.va_notify.notifications.delivered')
        end

        it 'updates va_notify_status' do
          described_class.call(notification_record)
          es = EvidenceSubmission.find_by(va_notify_id: notification_record.notification_id)
          expect(es.va_notify_status).to eq(BenefitsDocuments::Constants::VANOTIFY_STATUS[:SUCCESS])
        end
      end

      context 'temporary-failure' do
        let!(:notification_record) do
          build(:notification, status: 'temporary-failure', notification_id: SecureRandom.uuid)
        end

        let!(:evidence_submission) do
          create(:bd_evidence_submission_failed_va_notify_email_enqueued,
                 va_notify_id: notification_record.notification_id)
        end

        it 'logs error and increments StatsD' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          es = EvidenceSubmission.find_by(va_notify_id: notification_record.notification_id)
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.temporary_failure')
          expect(StatsD).to have_received(:increment)
            .with('callbacks.cst_document_uploads.va_notify.notifications.temporary_failure')
          expect(Rails.logger).to have_received(:error).with(
            'Lighthouse::EvidenceSubmissions::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type,
              request_id: es.request_id,
              job_class: es.job_class }
          )
        end
      end

      context 'other' do
        let!(:notification_record) do
          build(:notification, status: '', notification_id: SecureRandom.uuid)
        end

        let!(:evidence_submission) do
          create(:bd_evidence_submission_failed_va_notify_email_enqueued,
                 va_notify_id: notification_record.notification_id)
        end

        it 'logs error and increments StatsD' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          es = EvidenceSubmission.where(va_notify_id: notification_record.notification_id).first
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.other')
          StatsD.increment('callbacks.cst_document_uploads.va_notify.notifications.other')
          expect(Rails.logger).to have_received(:error).with(
            'Lighthouse::EvidenceSubmissions::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type,
              request_id: es.request_id,
              job_class: es.job_class }
          )
        end
      end
    end
  end
end
