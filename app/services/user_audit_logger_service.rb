# frozen_string_literal: true

class UserAuditLoggerService
  def self.log_user_action(details:, acting_user_verification: nil, subject_user_verification:,
                           status:, acting_ip_address:, acting_user_agent:)
    user_action_event = UserActionEvent.create!(details:)
    UserAction.create!(acting_user_verification:,
                       subject_user_verification:,
                       status:,
                       user_action_event:,
                       acting_ip_address:,
                       acting_user_agent:)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[UserAuditLoggerService] Validation Error: #{e.message}",
                       { subject_user_verification: subject_user_verification&.credential_identifier })
    raise e
  end
end
