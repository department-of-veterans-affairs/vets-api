# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'sm/client_session'
require 'sm/configuration'
require 'vets/collection'

module SM
  ##
  # Core class responsible for SM API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient

    configuration SM::Configuration
    client_session SM::ClientSession

    MHV_MAXIMUM_PER_PAGE = 250
    CONTENT_DISPOSITION = 'attachment; filename='
    STATSD_KEY_PREFIX = if instance_of? SM::Client
                          'api.sm'
                        else
                          'mobile.sm'
                        end

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
                              frequency:)
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

    ##
    # Fetch current message signature
    #
    # @return [Sting] json response
    #
    def get_signature
      perform(:get, 'preferences/signature', nil, token_headers).body
    end

    ##
    # Update current message signature
    #
    # @return [Sting] json response
    #
    def post_signature(params)
      request_body = MessagingSignature.new(params).to_json
      perform(:post, 'preferences/signature', request_body, token_headers).body
    end
    # @!endgroup

    ##
    # @!group Folders
    ##
    # Get a collection of Folders
    #
    # @return [Common::Collection[Folder]]
    #
    def get_folders(user_uuid, use_cache, requires_oh_messages = nil)
      path = 'folder'
      path = append_requires_oh_messages_query(path, requires_oh_messages)

      cache_key = "#{user_uuid}-folders"
      get_cached_or_fetch_data(use_cache, cache_key, Folder) do
        json = perform(:get, path, nil, token_headers).body
        data = Vets::Collection.new(json[:data], Folder, metadata: json[:metadata], errors: json[:errors])
        Folder.set_cached(cache_key, data)
        data
      end
    end

    ##
    # Get a single Folder
    #
    # @return [Folder]
    #
    def get_folder(id, requires_oh_messages = nil)
      path = "folder/#{id}"
      path = append_requires_oh_messages_query(path, requires_oh_messages)

      json = perform(:get, path, nil, token_headers).body
      Folder.new(json[:data].merge(json[:metadata]))
    end

    ##
    # Create a Folder
    #
    # @param name [String] name for the folder
    # @return [Folder]
    #
    def post_create_folder(name)
      json = perform(:post, 'folder', { 'name' => name }, token_headers).body
      Folder.new(json[:data].merge(json[:metadata]))
    end

    ##
    # Rename a Folder
    #
    # @param folder_id [Fixnum] id of the Folder
    # @param name [String] new name for the folder
    # @return [Folder]
    #
    def post_rename_folder(folder_id, name)
      json = perform(:post, "folder/#{folder_id}/rename", { 'folderName' => name }, token_headers).body
      Folder.new(json[:data].merge(json[:metadata]))
    end

    ##
    # Delete a Folder
    #
    # @param id [Fixnum] id of the Folder
    # @return [Fixnum] the status code of the response
    #
    def delete_folder(id)
      response = perform(:delete, "folder/#{id}", nil, token_headers)
      response&.status
    end

    ##
    # Get a collection of Messages
    #
    # @return [Common::Collection]
    #
    def get_folder_messages(user_uuid, folder_id, use_cache)
      cache_key = "#{user_uuid}-folder-messages-#{folder_id}"
      get_cached_or_fetch_data(use_cache, cache_key, Message) do
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
        messages = Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
        Message.set_cached(cache_key, messages)
        messages
      end
    end

    ##
    # Get a collection of Threads
    #
    # @param folder_id [Fixnum] id of the user’s folder (0 Inbox, -1 Sent, -2 Drafts, -3 Deleted, > 0 for custom folder)
    # @param page_start [Fixnum] Pagination start numbering
    # @param page_end [Fixnum] Pagination end numbering (max: 100)
    # @param sort_field [String] field to sort results by (SENDER_NAME or RECIPIENT_NAME or SENT_DATE or DRAFT_DATE)
    # @param sort_order [String] order to sort results by (ASC for Ascending or DESC for Descending)
    #
    # @return [Common::Collection]
    #
    def get_folder_threads(folder_id, params)
      base_path = "folder/threadlistview/#{folder_id}"
      query_params = [
        "pageSize=#{params[:page_size]}",
        "pageNumber=#{params[:page_number]}",
        "sortField=#{params[:sort_field]}",
        "sortOrder=#{params[:sort_order]}"
      ].join('&')
      path = "#{base_path}?#{query_params}"
      path = append_requires_oh_messages_query(path, params[:requires_oh_messages])

      json = perform(:get, path, nil, token_headers).body

      Vets::Collection.new(json[:data], MessageThread, metadata: json[:metadata], errors: json[:errors])
    end

    ##
    # Run a search of messages in the given folder
    #
    # @param folder_id [Fixnum] id of the folder to search
    # @param page_num [Fixnum] page number of results to return
    # @param page_size [Fixnum] number of messages per page
    # @param args [Hash] arguments for the message search
    # @return [Common::Collection]
    #
    def post_search_folder(folder_id, page_num, page_size, args = {}, requires_oh_messages = nil)
      page_num ||= 1
      page_size ||= MHV_MAXIMUM_PER_PAGE

      path = "folder/#{folder_id}/searchMessage/page/#{page_num}/pageSize/#{page_size}"
      path = append_requires_oh_messages_query(path, requires_oh_messages)

      json = perform(:post,
                          path,
                          args.to_h,
                          token_headers).body
      Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
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
      draft.as_reply
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
      Category.new(json[:data])
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
      Message.new(json[:data].merge(json[:metadata]))
    end

    ##
    # Get a message thread old api
    #
    # @param id [Fixnum] message id
    # @return [Common::Collection[Message]]
    #
    def get_message_history(id)
      path = "message/#{id}/history"
      json = perform(:get, path, nil, token_headers).body
      Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
    end

    ##
    # Get a message thread
    #
    # @param id [Fixnum] message id
    # @return [Common::Collection[MessageThread]]
    #
    def get_messages_for_thread(id, requires_oh_messages = nil)
      path = "message/#{id}/messagesforthread"
      path = append_requires_oh_messages_query(path, requires_oh_messages)

      json = perform(:get, path, nil, token_headers).body
      Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata], errors: json[:errors])
    end

    ##
    # Get a message thread with full body and attachments
    #
    # @param id [Fixnum] message id
    # @return [Common::Collection[MessageThreadDetails]]
    #
    def get_full_messages_for_thread(id, requires_oh_messages = nil)
      path = "message/#{id}/allmessagesforthread/1"
      path = append_requires_oh_messages_query(path, requires_oh_messages)
      json = perform(:get, path, nil, token_headers).body
      Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata], errors: json[:errors])
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

      json = perform(:post, 'message', args.to_h, token_headers).body
      Message.new(json[:data].merge(json[:metadata]))
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
      json = perform(:post, 'message/attach', args.to_h, custom_headers).body
      Message.new(json[:data].merge(json[:metadata]))
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
      json = perform(:post, "message/#{id}/reply/attach", args.to_h, custom_headers).body
      Message.new(json[:data].merge(json[:metadata]))
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

      json = perform(:post, "message/#{id}/reply", args.to_h, token_headers).body
      Message.new(json[:data].merge(json[:metadata]))
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

      response&.status
    end

    ##
    # Move a thread to a given folder
    #
    # @param id [Fixnum] the thread id
    # @param folder_id [Fixnum] the {Folder} id
    # @return [Fixnum] the response status code
    #
    def post_move_thread(id, folder_id)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, "message/#{id}/movethreadmessages/tofolder/#{folder_id}", nil, custom_headers)
      response&.status
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

      response&.status
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
      filename = response.response_headers['content-disposition'].gsub(CONTENT_DISPOSITION, '').gsub(/%22|"/, '')
      { body: response.body, filename: }
    end
    # @!endgroup

    ##
    # @!group Triage Teams
    ##
    # Get a collection of triage team recipients
    #
    # @return [Common::Collection[TriageTeam]]
    #
    def get_triage_teams(user_uuid, use_cache)
      cache_key = "#{user_uuid}-triage-teams"
      get_cached_or_fetch_data(use_cache, cache_key, TriageTeam) do
        json = perform(:get, 'triageteam', nil, token_headers).body
        data = Vets::Collection.new(json[:data], TriageTeam, metadata: json[:metadata], errors: json[:errors])
        TriageTeam.set_cached(cache_key, data)
        data
      end
    end

    ##
    # Get a collection of all triage team recipients, including blocked
    # with detailed attributes per each team
    # including a total tally of associated and locked teams
    #
    # @return [Common::Collection[AllTriageTeams]]
    #
    def get_all_triage_teams(user_uuid, use_cache, requires_oh = nil)
      cache_key = "#{user_uuid}-all-triage-teams"
      get_cached_or_fetch_data(use_cache, cache_key, AllTriageTeams) do
        path = 'alltriageteams'
        if requires_oh == '1'
          separator = path.include?('?') ? '&' : '?'
          path += "#{separator}requiresOHTriageGroup=#{requires_oh}"
        end
        json = perform(:get, path, nil, token_headers).body
        data = Vets::Collection.new(json[:data], AllTriageTeams, metadata: json[:metadata], errors: json[:errors])
        AllTriageTeams.set_cached(cache_key, data)
        data
      end
    end
    # @!endgroup

    ##
    # Update preferredTeam value for a patient's list of triage teams
    #
    # @param updated_triage_teams_list [Array] an array of objects
    # with triage_team_id and preferred_team values
    # @return [Fixnum] the response status code
    #
    def update_triage_team_preferences(updated_triage_teams_list)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, 'preferences/patientpreferredtriagegroups', updated_triage_teams_list, custom_headers)
      response&.status
    end
    # @!endgroup

    def get_cached_or_fetch_data(use_cache, cache_key, model)
      data = nil
      data = model.get_cached(cache_key) if use_cache

      if data
        Rails.logger.info("secure messaging #{model} cache fetch", cache_key)
        statsd_cache_hit
        Vets::Collection.new(data, model)
      else
        Rails.logger.info("secure messaging #{model} service fetch", cache_key)
        statsd_cache_miss
        yield
      end
    end

    def get_session_tagged
      Sentry.set_tags(error: 'mhv_sm_session')
      current_user = User.find(session.user_uuid)

      requires_oh_messages = '0'
      if current_user.present? && Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, current_user)
        requires_oh_messages = '1'
      end

      Rails.logger.info("secure messaging session tagged with requiresOHMessages=#{requires_oh_messages}")
      path = append_requires_oh_messages_query('session', requires_oh_messages)
      env = perform(:get, path, nil, auth_headers)
      Sentry.get_current_scope.tags.delete(:error)
      env
    end

    private

    def auth_headers
      headers = config.base_request_headers.merge(
        'appToken' => config.app_token,
        'mhvCorrelationId' => session.user_id.to_s
      )
      if Flipper.enabled?(:mhv_secure_messaging_migrate_to_api_gateway)
        headers.merge('x-api-key' => config.x_api_key)
      else
        headers
      end
    end

    def token_headers
      headers = config.base_request_headers.merge(
        'Token' => session.token
      )
      if Flipper.enabled?(:mhv_secure_messaging_migrate_to_api_gateway)
        headers.merge('x-api-key' => config.x_api_key)
      else
        headers
      end
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
      if args[:id].present? && reply_draft?(args[:id])
        draft = MessageDraft.new(args.merge(has_message: true)).as_reply
        draft.errors.add(:base, 'attempted to use reply draft in send message')
        raise Common::Exceptions::ValidationErrors, draft
      end
    end

    def append_requires_oh_messages_query(path, requires_oh_messages = nil)
      if requires_oh_messages == '1'
        separator = path.include?('?') ? '&' : '?'
        path += "#{separator}requiresOHMessages=#{requires_oh_messages}"
      end
      path
    end

    def validate_reply_context(args)
      if args[:id].present? && !reply_draft?(args[:id])
        draft = MessageDraft.new(args)
        draft.errors.add(:base, 'attempted to use plain draft in send reply')
        raise Common::Exceptions::ValidationErrors, draft
      end
    end

    ##
    # @!group StatsD
    ##
    # Report stats of secure messaging events
    #

    def statsd_cache_hit
      StatsD.increment("#{STATSD_KEY_PREFIX}.cache.hit")
    end

    def statsd_cache_miss
      StatsD.increment("#{STATSD_KEY_PREFIX}.cache.miss")
    end
    # @!endgroup
  end
end
