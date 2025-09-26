# frozen_string_literal: true

module SM
  class Client
    module ValidationAndAuth
      private

      def auth_headers
        config.base_request_headers.merge(
          'appToken' => config.app_token,
          'mhvCorrelationId' => session.user_id.to_s,
          'x-api-key' => config.x_api_key
        )
      end

      def token_headers
        config.base_request_headers.merge(
          'Token' => session.token,
          'x-api-key' => config.x_api_key
        )
      end

      def reply_draft?(id)
        get_message_history(id).records.present?
      end

      def validate_draft(args)
        draft = MessageDraft.new(args)
        draft.as_reply if args[:id] && reply_draft?(args[:id])
        raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
      end

      def validate_reply_draft(args)
        draft = MessageDraft.new(args).as_reply
        draft.has_message = !args[:id] || reply_draft?(args[:id])
        raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
      end

      def validate_create_context(args)
        return unless args[:id].present? && reply_draft?(args[:id])

        draft = MessageDraft.new(args.merge(has_message: true)).as_reply
        draft.errors.add(:base, 'attempted to use reply draft in send message')
        raise Common::Exceptions::ValidationErrors, draft
      end

      def validate_reply_context(args)
        return unless args[:id].present? && !reply_draft?(args[:id])

        draft = MessageDraft.new(args)
        draft.errors.add(:base, 'attempted to use plain draft in send reply')
        raise Common::Exceptions::ValidationErrors, draft
      end

      def append_requires_oh_messages_query(path, param_name = 'requiresOHMessages')
        current_user = User.find(session.user_uuid)
        if current_user.present? && Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, current_user)
          separator = path.include?('?') ? '&' : '?'
          path += "#{separator}#{param_name}=1"
        end
        path
      end

      def get_session_tagged
        Sentry.set_tags(error: 'mhv_sm_session')
        path = append_requires_oh_messages_query('session')
        env = perform(:get, path, nil, auth_headers)
        Sentry.get_current_scope.tags.delete(:error)
        env
      end
    end
  end
end
