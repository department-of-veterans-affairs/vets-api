# frozen_string_literal: true

module UserAudit
  class Appender < SemanticLogger::Subscriber
    def initialize(filter: /UserAudit/, level: :info, **args, &)
      super(filter:, level:, **args, &)
    end

    def log(log)
      payload = log.payload
      tags = log.named_tags

      user_action_event_id = UserActionEvent.find_by(identifier: payload[:identifier])&.id

      UserAction.create(
        user_action_event_id:,
        acting_user_verification_id: payload[:acting_user_verification_id],
        subject_user_verification_id: payload[:subject_user_verification_id],
        status: payload[:status],
        acting_ip_address: tags[:ip],
        acting_user_agent: tags[:user_agent]
      )
    end

    def should_log?(log)
      payload = log.payload

      return false if payload[:status].blank?
      return false if payload[:identifier].blank?
      return false if payload[:subject_user_verification_id].blank?

      super(log)
    end

    private

    def default_formatter
      SemanticLogger::Formatters::Json.new
    end
  end
end
