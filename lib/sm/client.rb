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
      perform(:post, 'preferences/signature', params.to_h, token_headers).body
    end
    # @!endgroup

    ##
    # @!group Folders
    ##
    # Get a collection of Folders
    #
    # @return [Common::Collection[Folder]]
    #
    def get_folders(user_uuid, use_cache)
      path = 'folder'
      path = append_requires_oh_messages_query(path)

      cache_key = "#{user_uuid}-folders"
      get_cached_or_fetch_data(use_cache, cache_key, Folder) do
        json = perform(:get, path, nil, token_headers).body
        data = Vets::Collection.new(json[:data], Folder, metadata: json[:metadata], errors: json[:errors])
        Folder.set_cached(cache_key, data.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
        data
      end
    end

    ##
    # Get a single Folder
    #
    # @return [Folder]
    #
    def get_folder(id)
      path = "folder/#{id}"
      path = append_requires_oh_messages_query(path)

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
        Message.set_cached(cache_key, messages.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
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
      path = append_requires_oh_messages_query(path)

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
    def post_search_folder(folder_id, page_num, page_size, args = {})
      page_num ||= 1
      page_size ||= MHV_MAXIMUM_PER_PAGE

      path = "folder/#{folder_id}/searchMessage/page/#{page_num}/pageSize/#{page_size}"
      path = append_requires_oh_messages_query(path)

      json = perform(:post,
                     path,
                     args.attributes,
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
      draft.body = json[:data][:body]
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
    def get_messages_for_thread(id)
      path = "message/#{id}/messagesforthread"
      path = append_requires_oh_messages_query(path)

      json = perform(:get, path, nil, token_headers).body
      Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata], errors: json[:errors])
    end

    ##
    # Get a message thread with full body and attachments
    #
    # @param id [Fixnum] message id
    # @return [Common::Collection[MessageThreadDetails]]
    #
    def get_full_messages_for_thread(id)
      path = "message/#{id}/allmessagesforthread/1"
      path = append_requires_oh_messages_query(path)
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
    def post_create_message(args = nil, poll_for_status: false, **kwargs)
      args = (args || {}).merge(kwargs)
      validate_create_context(args)
      json = perform(:post, 'message', args.to_h, token_headers).body
      message = Message.new(json[:data].merge(json[:metadata]))
      return poll_status(message) if poll_for_status && message.is_oh_message

      message
    end

    ##
    # Create a message with an attachment
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
    #
    def post_create_message_with_attachment(args = nil, poll_for_status: false, **kwargs)
      args = (args || {}).merge(kwargs)
      validate_create_context(args)
      Rails.logger.info('MESSAGING: post_create_message_with_attachments')
      custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
      json = perform(:post, 'message/attach', args.to_h, custom_headers).body
      message = Message.new(json[:data].merge(json[:metadata]))
      return poll_status(message) if poll_for_status && message.is_oh_message

      message
    end

    ##
    # Create a presigned URL for an attachment
    # # @param file [ActionDispatch::Http::UploadedFile] the file to be uploaded
    # @return [String] the MHV S3 presigned URL for the attachment
    #
    def create_presigned_url_for_attachment(file)
      attachment_name = File.basename(file.original_filename, File.extname(file.original_filename))
      file_extension = File.extname(file.original_filename).delete_prefix('.')

      query_params = {
        attachmentName: attachment_name,
        fileExtension: file_extension
      }

      perform(:get, 'attachment/presigned-url', query_params, token_headers).body
    end

    ##
    # Create a message with attachments
    # Utilizes MHV S3 presigned URLs to upload large attachments
    # bypassing the 10MB limit of the MHV API gateway limitation
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
    #
    def post_create_message_with_lg_attachments(args = nil, poll_for_status: false, **kwargs)
      args = (args || {}).merge(kwargs)
      validate_create_context(args)
      Rails.logger.info('MESSAGING: post_create_message_with_lg_attachments')
      message = create_message_with_lg_attachments_request('message/attach', args)
      return poll_status(message) if poll_for_status && message.is_oh_message

      message
    end

    ##
    # Create a message reply with an attachment
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
    #
    def post_create_message_reply_with_attachment(id, args = nil, poll_for_status: false, **kwargs)
      args = (args || {}).merge(kwargs)
      validate_reply_context(args)
      Rails.logger.info('MESSAGING: post_create_message_reply_with_attachment')
      custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
      json = perform(:post, "message/#{id}/reply/attach", args.to_h, custom_headers).body
      message = Message.new(json[:data].merge(json[:metadata]))
      return poll_status(message) if poll_for_status && message.is_oh_message

      message
    end

    ##
    # Create a message reply with attachments
    # Utilizes MHV S3 presigned URLs to upload large attachments
    # bypassing the 10MB limit of the MHV API gateway limitation
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message create context is invalid
    #
    def post_create_message_reply_with_lg_attachment(id, args = nil, poll_for_status: false, **kwargs)
      args = (args || {}).merge(kwargs)
      validate_reply_context(args)
      Rails.logger.info('MESSAGING: post_create_message_reply_with_lg_attachment')
      message = create_message_with_lg_attachments_request("message/#{id}/reply/attach", args)
      return poll_status(message) if poll_for_status && message.is_oh_message

      message
    end

    ##
    # Create a message reply
    #
    # @param args [Hash] a hash of message arguments
    # @return [Message]
    # @raise [Common::Exceptions::ValidationErrors] if message reply context is invalid
    #
    def post_create_message_reply(id, args = nil, poll_for_status: false, **kwargs)
      args = (args || {}).merge(kwargs)
      validate_reply_context(args)
      json = perform(:post, "message/#{id}/reply", args.to_h, token_headers).body
      message = Message.new(json[:data].merge(json[:metadata]))
      return poll_status(message) if poll_for_status && message.is_oh_message

      message
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
    # Endpoint returns either a binary file response, or object with AWS S3 URL details.
    # If the response is a URL (string or object format), it will fetch the file from that URL.
    # Object format includes: { "url": URL, "mimeType": "application/pdf", "name": "filename.pdf" }
    # 10MB limit of the MHV API gateway.
    #
    # @param message_id [Fixnum] the message id
    # @param attachment_id [Fixnum] the attachment id
    # @return [Hash] an object with binary file content and filename { body: binary_data, filename: string }
    #
    def get_attachment(message_id, attachment_id)
      path = "message/#{message_id}/attachment/#{attachment_id}"
      response = perform(:get, path, nil, token_headers)
      data = response.body[:data] if response.body.is_a?(Hash)

      # Attachments that are stored in AWS S3 via presigned URL return an object with URL details
      if data.is_a?(Hash) && data[:url] && data[:mime_type] && data[:name]
        url = data[:url]
        uri = URI.parse(url)
        file_response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.get(uri.request_uri)
        end
        unless file_response.is_a?(Net::HTTPSuccess)
          Rails.logger.error('Failed to fetch attachment from presigned URL')
          raise Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_URL_FETCH_ERROR', {},
                                                                file_response.code)
        end
        filename = data[:name]
        return { body: file_response.body, filename: }
      end

      # Default: treat as binary file response
      filename = response.response_headers['content-disposition']&.gsub(CONTENT_DISPOSITION, '')&.gsub(/%22|"/, '')
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
        TriageTeam.set_cached(cache_key, data.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
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
    def get_all_triage_teams(user_uuid, use_cache)
      cache_key = "#{user_uuid}-all-triage-teams"
      get_cached_or_fetch_data(use_cache, cache_key, AllTriageTeams) do
        path = append_requires_oh_messages_query('alltriageteams', 'requiresOHTriageGroup')
        json = perform(:get, path, nil, token_headers).body
        data = Vets::Collection.new(json[:data], AllTriageTeams, metadata: json[:metadata], errors: json[:errors])
        AllTriageTeams.set_cached(cache_key, data.records) unless Flipper.enabled?(:mhv_secure_messaging_no_cache)
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

    def get_unique_care_systems(all_recipients)
      unique_care_system_ids = all_recipients.uniq(&:station_number).map(&:station_number)
      unique_care_system_names = Mobile::FacilitiesHelper.get_facility_names(unique_care_system_ids)
      unique_care_system_ids.zip(unique_care_system_names).map! do |system|
        {
          station_number: system[0],
          health_care_system_name: system[1] || system[0]
        }
      end
    end

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
      path = append_requires_oh_messages_query('session')
      env = perform(:get, path, nil, auth_headers)
      Sentry.get_current_scope.tags.delete(:error)
      env
    end

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
      if args[:id].present? && reply_draft?(args[:id])
        draft = MessageDraft.new(args.merge(has_message: true)).as_reply
        draft.errors.add(:base, 'attempted to use reply draft in send message')
        raise Common::Exceptions::ValidationErrors, draft
      end
    end

    def append_requires_oh_messages_query(path, param_name = 'requiresOHMessages')
      current_user = User.find(session.user_uuid)
      if current_user.present? && Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, current_user)
        separator = path.include?('?') ? '&' : '?'
        path += "#{separator}#{param_name}=1"
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
    # Upload an attachment to S3 using a presigned URL
    # @param file [ActionDispatch::Http::UploadedFile] the file to be uploaded
    def upload_attachment_to_s3(file, presigned_url)
      uri = URI.parse(presigned_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      request = Net::HTTP::Put.new(uri)
      request['Content-Type'] = file.content_type
      request.body_stream = file
      request.content_length = file.size

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("Failed to upload Messaging attachment to S3: \\#{response.body}")
        raise Common::Exceptions::BackendServiceException.new('SM_UPLOAD_ATTACHMENT_ERROR', 500)
      end
    end

    def extract_uploaded_file_name(url)
      URI.parse(url).path.split('/').last
    end

    def build_lg_attachment(file)
      url = create_presigned_url_for_attachment(file)[:data]
      uploaded_file_name = extract_uploaded_file_name(url)
      upload_attachment_to_s3(file, url)
      {
        'attachmentName' => file.original_filename,
        'mimeType' => file.content_type,
        'size' => file.size,
        'lgAttachmentId' => uploaded_file_name
      }
    end

    def camelize_keys(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end

    def form_large_attachment_payload(message, lg_attachments)
      camelized_message = camelize_keys(message)
      {
        'message' => Faraday::Multipart::ParamPart.new(
          camelized_message.to_json(camelize: true),
          'application/json'
        ),
        'lgAttachments[]' => Faraday::Multipart::ParamPart.new(
          lg_attachments.to_json,
          'application/json'
        )
      }
    end

    def create_message_with_lg_attachments_request(path, args)
      uploads = args.delete(:uploads)
      raise Common::Exceptions::ValidationErrors, 'uploads must be an array' unless uploads.is_a?(Array)

      # Parallel upload of attachments
      require 'concurrent-ruby'
      futures = uploads.map { |file| Concurrent::Promises.future { build_lg_attachment(file) } }
      lg_attachments = Concurrent::Promises.zip(*futures).value!

      # Build multipart payload
      payload = form_large_attachment_payload(args[:message], lg_attachments)
      custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
      json = perform(:post, path, payload, custom_headers).body
      Message.new(json[:data].merge(json[:metadata]))
    end

    ##
    # @!group Message Status
    ##
    # Poll OH message status until terminal state or timeout
    #
    def get_message_status(message_id)
      path = "messages/#{message_id}/status"
      json = perform(:get, path, nil, token_headers).body
      data = json.is_a?(Hash) && json[:data].present? ? json[:data] : json
      {
        message_id: data[:message_id] || data[:id] || message_id,
        status: data[:status]&.to_s&.upcase,
        is_oh_message: data.key?(:is_oh_message) ? data[:is_oh_message] : data[:oh_message],
        oh_secure_message_id: data[:oh_secure_message_id]
      }
    end

    def poll_message_status(message_id, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      terminal_statuses = %w[SENT FAILED INVALID UNKNOWN NOT_SUPPORTED]
      deadline = Time.zone.now + timeout_seconds
      consecutive_errors = 0

      loop do
        raise Common::Exceptions::GatewayTimeout if Time.zone.now >= deadline

        begin
          result = get_message_status(message_id)
          status = result[:status]
          return result if status && terminal_statuses.include?(status)

          consecutive_errors = 0
        rescue Common::Exceptions::GatewayTimeout
          # Immediately re-raise upstream timeouts
          raise
        rescue
          consecutive_errors += 1
          raise Common::Exceptions::GatewayTimeout if consecutive_errors > max_errors
        end

        sleep interval_seconds
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

    # Polling integration for OH messages on send/reply
    def poll_status(message)
      result = poll_message_status(message.id, timeout_seconds: 60, interval_seconds: 1, max_errors: 2)
      status = result && result[:status]
      raise Common::Exceptions::UnprocessableEntity if %w[FAILED INVALID].include?(status)

      message
    end

    public :get_message_status, :poll_message_status
    # @!endgroup
  end
end
