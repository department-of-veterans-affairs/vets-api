# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing message draft-related methods for the SM Client
    #
    module MessageDrafts
      ##
      # Create and update a new message draft
      #
      # @param args [Hash] arguments for the message draft
      # @raise [Common::Exceptions::ValidationErrors] if the draft is not valid
      # @return [MessageDraft]
      #
      def post_create_message_draft(args = {})
        # Prevent call if this is a reply draft, otherwise reply-to message subject can change.
        validate_draft(args)

        json = perform(:post, 'message/draft', args, token_headers).body
        draft = MessageDraft.new(json[:data].merge(json[:metadata]))
        draft.body = json[:data][:body]
        draft
      end

      ##
      # Create and update a new message draft reply
      #
      # @param id [Fixnum] id of the message for which the reply is directed
      # @param args [Hash] arguments for the message draft reply
      # @raise [Common::Exceptions::ValidationErrors] if the draft reply is not valid
      # @return [MessageDraft]
      #
      def post_create_message_draft_reply(id, args = {})
        # prevent call if this an existing draft with no association to a reply-to message
        validate_reply_draft(args)

        json = perform(:post, "message/#{id}/replydraft", args, token_headers).body
        json[:data][:has_message] = true

        draft = MessageDraft.new(json[:data].merge(json[:metadata]))
        draft.body = json[:data][:body]
        draft.as_reply
      end

      private

      def validate_draft(args)
        draft = ::MessageDraft.new(args)
        draft.as_reply if args[:id] && reply_draft?(args[:id])
        raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
      end

      def validate_reply_draft(args)
        draft = ::MessageDraft.new(args).as_reply
        draft.has_message = !args[:id] || reply_draft?(args[:id])
        raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
      end
    end
  end
end
