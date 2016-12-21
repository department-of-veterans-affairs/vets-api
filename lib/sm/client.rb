# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'sm/client_session'
require 'sm/configuration'

module SM
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration SM::Configuration
    client_session SM::ClientSession

    MHV_MAXIMUM_PER_PAGE = 250
    CONTENT_DISPOSITION = 'attachment; filename='

    # Folders

    def get_folders
      json = perform(:get, 'folder', nil, token_headers).body
      Common::Collection.new(Folder, json)
    end

    def get_folder(id)
      json = perform(:get, "folder/#{id}", nil, token_headers).body
      Folder.new(json)
    end

    def post_create_folder(name)
      json = perform(:post, 'folder', { 'name' => name }, token_headers).body
      Folder.new(json)
    end

    def delete_folder(id)
      response = perform(:delete, "folder/#{id}", nil, token_headers)
      response.nil? ? nil : response.status
    end

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

    # Message Drafts

    def post_create_message_draft(args = {})
      # Prevent call if this is a reply draft, otherwise reply-to message suject can change.
      validate_draft(args)

      json = perform(:post, 'message/draft', args, token_headers).body
      MessageDraft.new(json)
    end

    def post_create_message_draft_reply(id, args = {})
      # prevent call if this an existing draft with no association to a reply-to message
      validate_reply_draft(args)

      json = perform(:post, "message/#{id}/replydraft", args, token_headers).body
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

    # Messages

    def get_categories
      path = 'message/category'

      json = perform(:get, path, nil, token_headers).body
      Category.new(json)
    end

    def get_message(id)
      path = "message/#{id}/read"
      json = perform(:get, path, nil, token_headers).body

      Message.new(json)
    end

    def get_message_history(id)
      path = "message/#{id}/history"
      json = perform(:get, path, nil, token_headers).body

      Common::Collection.new(Message, json)
    end

    def post_create_message(args = {})
      validate_create_context(args)

      json = perform(:post, 'message', args, token_headers).body
      Message.new(json)
    end

    def post_create_message_with_attachment(args = {})
      validate_create_context(args)

      custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
      json = perform(:post, 'message/attach', args, custom_headers).body
      Message.new(json)
    end

    def post_create_message_reply_with_attachment(id, args = {})
      validate_reply_context(args)

      custom_headers = token_headers.merge('Content-Type' => 'multipart/form-data')
      json = perform(:post, "message/#{id}/reply/attach", args, custom_headers).body
      Message.new(json)
    end

    def post_create_message_reply(id, args = {})
      validate_reply_context(args)

      json = perform(:post, "message/#{id}/reply", args, token_headers).body
      Message.new(json)
    end

    def post_move_message(id, folder_id)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, custom_headers)

      response.nil? ? nil : response.status
    end

    def delete_message(id)
      custom_headers = token_headers.merge('Content-Type' => 'application/json')
      response = perform(:post, "message/#{id}", nil, custom_headers)

      response.nil? ? nil : response.status
    end

    def get_attachment(message_id, attachment_id)
      path = "message/#{message_id}/attachment/#{attachment_id}"

      response = perform(:get, path, nil, token_headers)
      filename = response.response_headers['content-disposition'].gsub(CONTENT_DISPOSITION, '')
      { body: response.body, filename: filename }
    end

    def validate_create_context(args)
      if args[:id].present? && reply_draft?(args[:id])
        draft = MessageDraft.new(args.merge(has_message: true)).as_reply
        draft.errors.add(:base, 'attempted to use reply draft in send message')

        raise Common::Exceptions::ValidationErrors, draft
      end
    end

    def validate_reply_context(args)
      if args[:id].present? && !reply_draft?(args[:id])
        draft = MessageDraft.new(args)
        draft.errors.add(:base, 'attempted to use plain draft in send reply')

        raise Common::Exceptions::ValidationErrors, draft
      end
    end

    # Triage Teams

    def get_triage_teams
      json = perform(:get, 'triageteam', nil, token_headers).body
      Common::Collection.new(TriageTeam, json)
    end
  end
end
