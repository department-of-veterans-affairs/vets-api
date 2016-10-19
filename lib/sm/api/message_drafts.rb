# frozen_string_literal: true
module SM
  module API
    module MessageDrafts
      # post_create_message_draft: Creates a new draft, without attachments. If an id is included as
      # a parameter, then the message draft is updated.
      def post_create_message_draft(args = {})
        json = perform(:post, 'message/draft', args, token_headers).body

        MessageDraft.new(json)
      end

      def post_create_message_draft_reply(id, args = {})
        path = "message/#{id}/replydraft"
        json = perform(:post, path, args, token_headers).body

        MessageDraft.new(json)
      end
    end
  end
end
