# frozen_string_literal: true
module SM
  module API
    module MessageDrafts
      # post_create_message_draft: Creates a new draft, without attachments. If an id is included as
      # a parameter, then the message draft is updated.
      def post_create_message_draft(args = {})
        # Prevent call if this is a reply draft, otherwise reply-to message suject can change.
        draft = build_draft(args)
        return draft unless draft.valid?

        json = perform(:post, 'message/draft', args, token_headers)
        MessageDraft.new(json)
      end

      def post_create_message_draft_reply(id, args = {})
        # prevent call if this an existing draft with no association to a reply-to message
        draft = build_reply_draft(args)
        return draft unless draft.valid?

        json = perform(:post, "message/#{id}/replydraft", args, token_headers)
        json[:data][:has_message] = true

        MessageDraft.new(json).as_reply
      end

      def reply_draft?(id)
        get_message_history(id).data.present?
      end

      def build_draft(args)
        draft = MessageDraft.new(args)
        args[:id] && reply_draft?(args[:id]) ? draft.as_reply : draft
      end

      def build_reply_draft(args)
        draft = MessageDraft.new(args).as_reply
        draft.has_message = !args[:id] || reply_draft?(args[:id])

        draft
      end
    end
  end
end
