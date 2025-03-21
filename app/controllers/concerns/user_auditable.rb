# frozen_string_literal: true

module UserAuditable
  extend ActiveSupport::Concern

  included do
    class_attribute :user_audit_event_identifier # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :user_audit_event_controller_actions # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    around_action :log_user_audit_event, only: user_audit_event_controller_actions
  end

  class_methods do
    def audit_user_event(identifier, only:)
      self.user_audit_event_identifier = identifier
      self.user_audit_event_controller_actions = only
    end
  end

  private

  def log_user_audit_event
    identifier = self.class.user_audit_event_identifier
    acting_user_verification_id = current_user&.user_verification_id
    subject_user_verification_id = current_user&.user_verification_id

    if identifier.present? && subject_user_verification_id.present?
      UserAudit.logger.initial(identifier:, acting_user_verification_id:, subject_user_verification_id:)

      yield

      UserAudit.logger.success(identifier:, acting_user_verification_id:, subject_user_verification_id:)

    else
      yield
    end
  rescue
    UserAudit.logger.error(identifier:, acting_user_verification_id:, subject_user_verification_id:)
    raise
  end
end
