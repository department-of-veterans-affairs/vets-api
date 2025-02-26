# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_documents/va_notify_email_status_callback'
require 'lighthouse/benefits_documents/constants'

describe BenefitsDocuments::VANotifyEmailStatusCallback do
  describe '#call' do
    context 'notification callback' do
      let(:notification_type) { :error }
      let(:callback_metadata) { { notification_type: } }

      context 'permanent-failure' do
        let!(:notification_record) do
          build(:notification, status: 'permanent-failure', callback_metadata:)
        end
  
        let!(:evidence_submission) do
          create(:bd_evidence_submission_failed_va_notify_email_enqueued, va_notify_id: notification_record.notification_id)
        end

        it 'logs error and increments StatsD' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          es = EvidenceSubmission.where(va_notify_id: notification_record.notification_id).first
          expect(Rails.logger).to have_received(:error).with(
            'BenefitsDocuments::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type,
              request_id: es.request_id
            })
          expect(StatsD).to have_received(:increment).with('silent_failure', tags: ['service:claim-status', 'function: Lighthouse - VA Notify evidence upload failure email'])
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.permanent_failure')
        end

        it 'updates va_notify_status' do
          described_class.call(notification_record)
          es = EvidenceSubmission.where(va_notify_id: notification_record.notification_id).first
          expect(es.va_notify_status).to eq(BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
        end
      end

      context 'delivered' do
        let!(:notification_record) do
          build(:notification, status: 'delivered')
        end
  
        let!(:evidence_submission) do
          create(:bd_evidence_submission_failed_va_notify_email_enqueued, va_notify_id: notification_record.notification_id)
        end

        it 'logs success and increments StatsD' do
          allow(StatsD).to receive(:increment)
          described_class.call(notification_record)
          expect(StatsD).to have_received(:increment).with('silent_failure_avoided', tags: ['service:claim-status', 'function: Lighthouse - VA Notify evidence upload failure email'])
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.delivered')
        end
      end

      context 'temporary-failure' do
        let!(:notification_record) do
          build(:notification, status: 'temporary-failure')
        end
  
        let!(:evidence_submission) do
          create(:bd_evidence_submission_failed_va_notify_email_enqueued, va_notify_id: notification_record.notification_id)
        end

        it 'logs error and increments StatsD' do
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)
          described_class.call(notification_record)
          es = EvidenceSubmission.where(va_notify_id: notification_record.notification_id).first
          expect(StatsD).to have_received(:increment).with('api.vanotify.notifications.temporary_failure')
          expect(Rails.logger).to have_received(:error).with(
            'BenefitsDocuments::VANotifyEmailStatusCallback',
            { notification_id: notification_record.notification_id,
              source_location: notification_record.source_location,
              status: notification_record.status,
              status_reason: notification_record.status_reason,
              notification_type: notification_record.notification_type,
              request_id: es.request_id
            })
        end
      end
    end
  end
end
