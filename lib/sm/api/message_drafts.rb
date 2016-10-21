# frozen_string_literal: true
module SM
  module API
    module MessageDrafts
      # post_create_message_draft: Creates a new draft, without attachments. If an id is included as
      # a parameter, then the message draft is updated.
      def post_create_message_draft(args = {})
        # Prevent call if this is a reply draft, otherwise reply-to message suject can change.
        json = if args[:id].present? && history?(args[:id])
                 { data: args.merge(has_message: true) }
               else
                 perform(:post, 'message/draft', args, token_headers)
               end

        MessageDraft.new(json)
      end

      def post_create_message_draft_reply(id, args = {})
        # Allow call if this is a new reply draft, or an existing draft with an association to a reply-to message
        if args[:id].blank? || history?(args[:id])
          json = perform(:post, "message/#{id}/replydraft", args, token_headers)
          json[:data][:has_message] = true
        else
          json = { data: args }
        end

        MessageDraft.new(json).as_reply
      end

      def history?(id)
        get_message_history(id).data.present?
      end
    end
  end
end
