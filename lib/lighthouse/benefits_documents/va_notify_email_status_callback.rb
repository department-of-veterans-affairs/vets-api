# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'

module BenefitsDocuments
  class VANotifyEmailStatusCallback
    def self.call(notification)
      notification_id = notification.notification_id
      source_location = notification.source_location
      status = notification.status
      status_reason = notification.status_reason
      notification_type = notification.notification_type
      es = EvidenceSubmission.where(va_notify_id: notification_id).first
      request_id = es.request_id

      case notification.status
      when 'delivered'
        # success
        StatsD.increment('api.vanotify.notifications.delivered')
        tags = ['service:claim-status', 'function: Lighthouse - VA Notify evidence upload failure email']
        StatsD.increment('silent_failure_avoided', tags:)
      when 'permanent-failure'
        # delivery failed
        es.update(va_notify_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED])
        # logging
        StatsD.increment('api.vanotify.notifications.permanent_failure')
        tags = ['service:claim-status', 'function: Lighthouse - VA Notify evidence upload failure email']
        StatsD.increment('silent_failure', tags:)
        Rails.logger.error('BenefitsDocuments::VANotifyEmailStatusCallback',
          { notification_id:,
            source_location:,
            status:,
            status_reason:,
            notification_type:,
            request_id:
          })
      when 'temporary-failure'
        # the api will continue attempting to deliver - success is still possible
        StatsD.increment('api.vanotify.notifications.temporary_failure')
        Rails.logger.error('BenefitsDocuments::VANotifyEmailStatusCallback',
          { notification_id:,
            source_location:,
            status:,
            status_reason:,
            notification_type:,
            request_id:
          })
      else
        StatsD.increment('api.vanotify.notifications.other')
        Rails.logger.error('BenefitsDocuments::VANotifyEmailStatusCallback',
          { notification_id:,
            source_location:,
            status:,
            status_reason:,
            notification_type:,
            request_id:
          })
      end
    end
  end
end
