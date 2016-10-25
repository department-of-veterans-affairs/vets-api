# frozen_string_literal: true
module SM
  module API
    module MessageDrafts
      def post_create_message_draft(args = {})
        # Prevent call if this is a reply draft, otherwise reply-to message suject can change.
        validate_draft(args)

        json = perform(:post, 'message/draft', args, token_headers)
        MessageDraft.new(json)
      end

      def post_create_message_draft_reply(id, args = {})
        # prevent call if this an existing draft with no association to a reply-to message
        validate_reply_draft(args)

        json = perform(:post, "message/#{id}/replydraft", args, token_headers)
        json[:data][:has_message] = true

        MessageDraft.new(json).as_reply
      end

      def reply_draft?(id)
        get_message_history(id).data.present?
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
    end
  end
end
