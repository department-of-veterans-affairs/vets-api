# frozen_string_literal: true

module UserAudit
  module Appenders
    class UserActionAppender < Base
      private

      def append_log
        log = UserAction.create!(
          user_action_event_id: user_action_event.id,
          acting_user_verification:,
          subject_user_verification:,
          status:,
          acting_ip_address:,
          acting_user_agent:
        )

        Rails.logger.info('[UserAudit][Logger] User action created',
                          { event_id: user_action_event.id,
                            event_description: user_action_event.details,
                            status:,
                            user_action: log.id })
      end
    end
  end
end
