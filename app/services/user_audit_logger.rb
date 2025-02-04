# frozen_string_literal: true

class UserAuditLogger
  class Error < StandardError; end
  class MissingSubjectVerificationError < Error; end
  class MissingUserActionEventError < Error; end
  class MissingStatusError < Error; end

  attr_reader :user_action_event, :acting_user_verification, :subject_user_verification,
              :status, :acting_ip_address, :acting_user_agent

  def initialize(config)
    @user_action_event = config.fetch(:user_action_event)
    @acting_user_verification = config.fetch(:acting_user_verification)
    @subject_user_verification = config.fetch(:subject_user_verification)
    @status = config.fetch(:status)
    @acting_ip_address = config[:ip_address]
    @acting_user_agent = config[:user_agent]
  end

  def perform
    validate_required_fields
    create_user_action
  end

  private

  def validate_required_fields
    validate_user_action_event
    validate_subject_verification
    validate_status
  end

  def validate_user_action_event
    raise MissingUserActionEventError, 'User action event must be present' if user_action_event.nil?
  end

  def validate_subject_verification
    raise MissingSubjectVerificationError, 'Subject user must have a verification' if subject_user_verification.nil?
  end

  def validate_status
    raise MissingStatusError, 'Status must be present' if status.nil?
  end

  def create_user_action
    UserAction.create!(
      user_action_event:,
      acting_user_verification:,
      subject_user_verification:,
      status:,
      acting_ip_address:,
      acting_user_agent:
    )
  end
end
