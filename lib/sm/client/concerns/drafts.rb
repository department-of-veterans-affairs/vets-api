# frozen_string_literal: true

module SM
  class Client
    module Drafts
      ##
      # Create or update a message draft (non-reply context).
      # Validates against reply usage to prevent subject/body mutation of a reply draft.
      #
      # @param args [Hash] draft attributes (subject, body, recipient_id, category, id for updates, etc.)
      # @return [MessageDraft]
      # @raise [Common::Exceptions::ValidationErrors] if validation fails
      def post_create_message_draft(args = {})
        validate_draft(args)
        json = perform(:post, 'message/draft', args, token_headers).body
        draft = MessageDraft.new(json[:data].merge(json[:metadata]))
        draft.body = json[:data][:body]
        draft
      end

      ##
      # Create or update a reply draft for an existing message thread.
      # Ensures association to the reply-to message and prevents misuse of plain drafts.
      #
      # @param id [Integer] original message id to which the reply draft is associated
      # @param args [Hash] draft attributes
      # @return [MessageDraft] (marked as reply via #as_reply)
      # @raise [Common::Exceptions::ValidationErrors] if validation fails
      def post_create_message_draft_reply(id, args = {})
        validate_reply_draft(args)
        json = perform(:post, "message/#{id}/replydraft", args, token_headers).body
        json[:data][:has_message] = true
        draft = MessageDraft.new(json[:data].merge(json[:metadata]))
        draft.body = json[:data][:body]
        draft.as_reply
      end
    end
  end
end
