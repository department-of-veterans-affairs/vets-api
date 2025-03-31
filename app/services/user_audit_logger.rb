# frozen_string_literal: true

class UserAuditLogger
  attr_reader :user_action_event, :acting_user_verification, :subject_user_verification,
              :status, :acting_ip_address, :acting_user_agent

  # rubocop:disable Metrics/ParameterLists
  def initialize(user_action_event:, acting_user_verification:, subject_user_verification:,
                 status:, acting_ip_address:, acting_user_agent:)
    @user_action_event = user_action_event
    @acting_user_verification = acting_user_verification
    @subject_user_verification = subject_user_verification
    @status = status
    @acting_ip_address = acting_ip_address
    @acting_user_agent = acting_user_agent
  end
  # rubocop:enable Metrics/ParameterLists

  def perform
    validate_required_fields
    log_audit_entry
    user_action
  rescue => e
    Rails.logger.error('UserAuditLogger error', { error: e.message })
  end

  private

  def validate_required_fields
    validate_user_action_event
    validate_subject_verification
    validate_status
  end

  def validate_user_action_event
    raise 'User action event must be present' if user_action_event.nil?
  end

  def validate_subject_verification
    raise 'Subject user verification must be present' if subject_user_verification.nil?
  end

  def validate_status
    raise 'Status must be present' if status.nil?
  end

  def log_audit_entry
    Rails.logger.info('User audit log created', { user_action_event: user_action_event.id,
                                                  user_action_event_details: user_action_event.details,
                                                  status:,
                                                  user_action: user_action.id })
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
