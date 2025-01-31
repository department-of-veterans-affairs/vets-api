# frozen_string_literal: true

class UserAuditLogger
  class Error < StandardError; end
  class MissingSubjectVerificationError < Error; end

  def self.log(user_action_event_id:, acting_user:, subject_user:, status: :initial, ip_address: nil, user_agent: nil)
    raise MissingSubjectVerificationError, 'Subject user must have a verification' if subject_user.user_verification.nil?

    UserAction.create!(
      user_action_event_id: user_action_event_id,
      acting_user_verification: acting_user.user_verification,
      subject_user_verification: subject_user.user_verification,
      status: status,
      acting_ip_address: ip_address,
      acting_user_agent: user_agent
    )
  end
end