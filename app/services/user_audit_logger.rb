# frozen_string_literal: true

class UserAuditLogger
  attr_reader :user_action_event_identifier, :acting_user_verification, :subject_user_verification,
              :status, :acting_ip_address, :acting_user_agent

  # rubocop:disable Metrics/ParameterLists
  def initialize(user_action_event_identifier:, subject_user_verification:, status:, acting_ip_address:,
                 acting_user_agent:, acting_user_verification: nil)
    @user_action_event_identifier = user_action_event_identifier
    @acting_user_verification = acting_user_verification.presence || subject_user_verification
    @subject_user_verification = subject_user_verification
    @status = status
    @acting_ip_address = acting_ip_address
    @acting_user_agent = acting_user_agent
  end
  # rubocop:enable Metrics/ParameterLists

  def perform
    subject_user_verification.validate!
    acting_user_verification.validate! if acting_user_verification != subject_user_verification
    log_audit_entry
    user_action
  rescue => e
    Rails.logger.error('[UserAuditLogger] error', { error: e.message })
  end

  private

  def log_audit_entry
    Rails.logger.info('User audit log created', { user_action_event: user_action_event.id,
                                                  user_action_event_details: user_action_event.details,
                                                  status:,
                                                  user_action: user_action.id })
  end

  def user_action_event
    @user_action_event ||= UserActionEvent.find_by(identifier: user_action_event_identifier)
  end

  def user_action
    @user_action ||= UserAction.create!(
      user_action_event:,
      acting_user_verification:,
      subject_user_verification:,
      status:,
      acting_ip_address:,
      acting_user_agent:
    )
  end
end
