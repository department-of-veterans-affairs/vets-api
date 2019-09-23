# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'sm/client_session'
require 'sm/configuration'

module SM
  ##
  # Core class responsible for SM API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration SM::Configuration
    client_session SM::ClientSession

    MHV_MAXIMUM_PER_PAGE = 250
    CONTENT_DISPOSITION = 'attachment; filename='

    ##
    # @!group Preferences
    ##
    # Fetch the list of available constant values for email frequency
    #
    # @return [Hash] an object containing the body of the response
    #
    def get_preferences_frequency_list
      perform(:get, 'preferences/notification/list', nil, token_headers).body
    end

    ##
    # Fetch the current email settings, including address and frequency
    #
    # @return [MessagingPreference]
    #
    def get_preferences
      json = perform(:get, 'preferences/notification', nil, token_headers).body
      frequency = MessagingPreference::FREQUENCY_GET_MAP[json[:data][:notify_me]]
      MessagingPreference.new(email_address: json[:data][:email_address],
                              frequency: frequency)
    end

    ##
    # Set the email address and frequency for getting emails.
    #
    # @param params [Hash] a hash of parameter objects
    # @example
    #   client.post_preferences(email_address: 'name@example.com', frequency: 'daily')
    # @return [MessagingPreference]
    # @raise [Common::Exceptions::ValidationErrors] if the email address is invalid
    # @raise [Common::Exceptions::BackendServiceException] if unhandled validation error is encountered in
    #   email_address, as mapped to SM152 code in config/locales/exceptions.en.yml
    #
    def post_preferences(params)
      mhv_params = MessagingPreference.new(params).mhv_params
      perform(:post, 'preferences/notification', mhv_params, token_headers)
      get_preferences
    end
    # @!endgroup

    ##
    # @!group Folders
    ##
    # Get a collection of Folders
    #
    # @return [Common::Collection[Folder]]
    #
    def get_folders
      json = perform(:get, 'folder', nil, token_headers).body
      Common::Collection.new(Folder, json)
    end

    ##
    # Get a single Folder
    #
    # @return [Folder]
    #
    def get_folder(id)
      json = perform(:get, "folder/#{id}", nil, token_headers).body
      Folder.new(json)
    end

    ##
    # Create a Folder
    #
    # @param name [String] name for the folder
    # @return [Folder]
    #
    def post_create_folder(name)
      json = perform(:post, 'folder', { 'name' => name }, token_headers).body
      Folder.new(json)
    end

    ##
    # Delete a Folder
    #
    # @param id [Fixnum] id of the Folder
    # @return [Fixnum] the status code of the response
    #
    def delete_folder(id)
      response = perform(:delete, "folder/#{id}", nil, token_headers)
      response.nil? ? nil : response.status
    end

    ##
    # Get a collection of Messages
    #
    # @return [Common::Collection]
    #
    def get_folder_messages(folder_id)
      page = 1
      json = { data: [], errors: {}, metadata: {} }

      loop do
        path = "folder/#{folder_id}/message/page/#{page}/pageSize/#{MHV_MAXIMUM_PER_PAGE}"
        page_data = perform(:get, path, nil, token_headers).body
        json[:data].concat(page_data[:data])
        json[:metadata].merge(page_data[:metadata])
        break unless page_data[:data].size == MHV_MAXIMUM_PER_PAGE

        page += 1
      end

      Common::Collection.new(Message, json)
    end
    # @!endgroup

    ##
    # @!group Message Drafts
    ##
    # Create and update a new message draft
    #
    # @param args [Hash] arguments for the message draft
    # @raise [Common::Exceptions::ValidationErrors] if the draft is not valid
    # @return [MessageDraft]
    #
    def post_create_message_draft(args = {})
      # Prevent call if this is a reply draft, otherwise reply-to message suject can change.
      validate_draft(args)

      json = perform(:post, 'message/draft', args, token_headers).body
      MessageDraft.new(json)
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

      MessageDraft.new(json).as_reply
    end

    private def reply_draft?(id)
      get_message_history(id).data.present?
    end

    private def validate_draft(args)
      draft = MessageDraft.new(args)
      draft.as_reply if args[:id] && reply_draft?(args[:id])
      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
    end

    private def validate_reply_draft(args)
      draft = MessageDraft.new(args).as_reply
      draft.has_message = !args[:id] || reply_draft?(args[:id])
      raise Common::Exceptions::ValidationErrors, draft unless draft.valid?
    end
    # @!endgroup

    ##
    # @!group Messages
    ##
    # Get message categories
    #
    # @return [Category]
    #
    def get_categories
      path = 'message/category'

      json = perform(:get, path, nil, token_headers).body
      Category.new(json)
    end

    ##
    # Get a message
    #
    # @param id [Fixnum] message id
    # @return [Message]
    #
    def get_message(id)
      path = "message/#{id}/read"
      json = perform(:get, path, nil, token_headers).body
      Message.new(json)
    end

    ##
    # Get a message thread
    #
    # @param id [Fixnum] message id
    # @return [Common::Collection[Message]]
    #
    def get_message_history(id)
      path = "message/#{id}/history"
      json = perform(:get, path, nil, token_headers).body
      Common::Collection.new(Message, json)
    end

    ##
    # Create a message
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
    #
    def post_create_message(args = {})
      validate_create_context(args)

      json = perform(:post, 'message', args, token_headers).body
      Message.new(json)
    end

    ##
    # Create a message with an attachment
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
    #
    def post_create_message_with_attachment(args = {})
      validate_create_context(args)

      custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
      json = perform(:post, 'message/attach', args, custom_headers).body
      Message.new(json)
    end

    ##
    # Create a message reply with an attachment
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
    #
    def post_create_message_reply_with_attachment(id, args = {})
      validate_reply_context(args)

      custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
      json = perform(:post, "message/#{id}/reply/attach", args, custom_headers).body
      Message.new(json)
    end

    ##
    # Create a message reply
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
    #
    def post_create_message_reply(id, args = {})
      validate_reply_context(args)

      json = perform(:post, "message/#{id}/reply", args, token_headers).body
      Message.new(json)
    end

    ##
    # Move a message to a given folder
    #
    # @param id [Fixnum] the {Message} id
    # @param folder_id [Fixnum] the {Folder} id
    # @return [Fixnum] the response status code
    #
    def post_move_message(id, folder_id)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, custom_headers)

      response.nil? ? nil : response.status
    end

    ##
    # Delete a message
    #
    # @param id [Fixnum] id of message to be deleted
    # @return [Fixnum] the response status code
    #
    def delete_message(id)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, "message/#{id}", nil, custom_headers)

      response.nil? ? nil : response.status
    end

    ##
    # Retrieve a message attachment
    #
    # @param message_id [Fixnum] the message id
    # @param attachment_id [Fixnum] the attachment id
    # @return [Hash] an object with attachment response details
    #
    def get_attachment(message_id, attachment_id)
      path = "message/#{message_id}/attachment/#{attachment_id}"

      response = perform(:get, path, nil, token_headers)
      filename = response.response_headers['content-disposition'].gsub(CONTENT_DISPOSITION, '')
      { body: response.body, filename: filename }
    end

    private def validate_create_context(args)
      if args[:id].present? && reply_draft?(args[:id])
        draft = MessageDraft.new(args.merge(has_message: true)).as_reply
        draft.errors.add(:base, 'attempted to use reply draft in send message')
        raise Common::Exceptions::ValidationErrors, draft
      end
    end

    private def validate_reply_context(args)
      if args[:id].present? && !reply_draft?(args[:id])
        draft = MessageDraft.new(args)
        draft.errors.add(:base, 'attempted to use plain draft in send reply')
        raise Common::Exceptions::ValidationErrors, draft
      end
    end
    # @!endgroup

    ##
    # @!group Triage Teams
    ##
    # Get a collection of triage team recipients
    #
    # @return [Common::Collection[TriageTeam]]
    #
    def get_triage_teams
      json = perform(:get, 'triageteam', nil, token_headers).body
      Common::Collection.new(TriageTeam, json)
    end
    # @!endgroup
  end
end
