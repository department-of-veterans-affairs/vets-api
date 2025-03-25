# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'

module Lighthouse
  module EvidenceSubmissions
    class VANotifyEmailStatusCallback
      def self.call(notification)
        es = EvidenceSubmission.find_by(va_notify_id: notification.notification_id)
        api_service_name = get_api_service_name(es.job_class)

        case notification.status
        when 'delivered'
          # success
          es.update(va_notify_status: BenefitsDocuments::Constants::VANOTIFY_STATUS[:SUCCESS])
          StatsD.increment('api.vanotify.notifications.delivered')
          StatsD.increment('callbacks.cst_document_uploads.va_notify.notifications.delivered')
          tags = ['service:claim-status', "function: #{api_service_name} - VA Notify evidence upload failure email"]
          StatsD.increment('silent_failure_avoided', tags:)
        when 'permanent-failure'
          # delivery failed
          es.update(va_notify_status: BenefitsDocuments::Constants::VANOTIFY_STATUS[:FAILED])
          StatsD.increment('api.vanotify.notifications.permanent_failure')
          StatsD.increment('callbacks.cst_document_uploads.va_notify.notifications.permanent_failure')
          tags = ['service:claim-status', "function: #{api_service_name} - VA Notify evidence upload failure email"]
          StatsD.increment('silent_failure', tags:)
        when 'temporary-failure'
          # the api will continue attempting to deliver - success is still possible
          StatsD.increment('api.vanotify.notifications.temporary_failure')
          StatsD.increment('callbacks.cst_document_uploads.va_notify.notifications.temporary_failure')
        else
          StatsD.increment('api.vanotify.notifications.other')
          StatsD.increment('callbacks.cst_document_uploads.va_notify.notifications.other')
        end

        add_log(notification, es) if notification.status != 'delivered'
      end

      def self.add_log(notification, evidence_submission)
        context = { 
          notification_id: notification.notification_id,
          source_location: notification.source_location,
          status: notification.status,
          status_reason: notification.status_reason,
          notification_type: notification.notification_type,
          request_id: evidence_submission.request_id,
          job_class: evidence_submission.job_class
        }

        Rails.logger.error(self.name, context)
      end

      def self.get_api_service_name(job_class)
        api_service_name = ''
        if job_class == 'EVSSClaimService'
          api_service_name = 'EVSS'
        elsif job_class == 'BenefitsDocuments::Service'
          api_service_name = 'Lighthouse'
        end

        api_service_name
      end
    end
  end
end
