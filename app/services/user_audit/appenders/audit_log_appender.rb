# frozen_string_literal: true

module UserAudit
  module Appenders
    class AuditLogAppender < Base
      private

      def append_log
        audit_log = Audit::Log.create!(
          subject_user_identifier:,
          subject_user_identifier_type:,
          acting_user_identifier:,
          acting_user_identifier_type:,
          event_id: user_action_event.identifier,
          event_description: user_action_event.details,
          event_status: status,
          event_occurred_at: log_time,
          message:
        )

        log_success('AuditLog created', event_id: user_action_event.id,
                                        event_description: user_action_event.details,
                                        status:,
                                        audit_log: audit_log.id)
      end

      def subject_user_identifier
        @subject_user_identifier = identifier_for(subject_user_account, subject_user_verification)
      end

      def acting_user_identifier
        @acting_user_identifier = if acting_user_verification == subject_user_verification
                                    subject_user_identifier
                                  else
                                    identifier_for(acting_user_account, acting_user_verification)
                                  end
      end

      def subject_user_identifier_type
        @subject_user_identifier_type = identifier_type_for(subject_user_account, subject_user_verification)
      end

      def acting_user_identifier_type
        @acting_user_identifier_type = if acting_user_verification == subject_user_verification
                                         subject_user_identifier_type
                                       else
                                         identifier_type_for(acting_user_account, acting_user_verification)
                                       end
      end

      def message
        mask_payload(payload).merge({ acting_ip_address:, acting_user_agent: })
      end

      def acting_user_account
        @acting_user_account = acting_user_verification.user_account
      end

      def subject_user_account
        @subject_user_account = subject_user_verification.user_account
      end

      def identifier_type_for(user_account, user_verification)
        return 'icn' if user_account.icn.present?

        case user_verification.credential_type
        when SAML::User::IDME_CSID         then 'idme_uuid'
        when SAML::User::LOGINGOV_CSID     then 'logingov_uuid'
        when SAML::User::MHV_ORIGINAL_CSID then 'mhv_id'
        end
      end

      def identifier_for(user_account, user_verification)
        user_account.icn || user_verification.credential_identifier
      end
    end
  end
end
