# frozen_string_literal: true

module UserAudit
  module Appenders
    class UserActionAppender < Base
      private

      def append_log
        UserAction.create!(
          user_action_event_id: user_action_event.id,
          acting_user_verification_id:,
          subject_user_verification_id:,
          status:,
          acting_ip_address:,
          acting_user_agent:
        )
      end
    end
  end
end
