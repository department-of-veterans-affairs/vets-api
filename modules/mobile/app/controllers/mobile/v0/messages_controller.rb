# frozen_string_literal: true

require 'unique_user_events'

module Mobile
  module V0
    class MessagesController < MessagingController
      include Filterable

      before_action :validate_message_id, only: %i[show destroy thread reply move]
      before_action :extend_timeout, only: %i[create reply], if: :oh_triage_group?

      def index
        resource = client.get_folder_messages(@current_user.uuid, params[:folder_id].to_s, use_cache?)
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        resource = resource.find_by(filter_params) if params[:filter].present?
        resource = resource.sort(params[:sort])

        links = pagination_links(resource)
        resource.metadata.merge!(message_counts(resource))
        # Add total_entries to metadata for backwards compatibility
        resource.metadata.merge!(total_entries(resource.size))

        # Log unique user event for inbox accessed
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_INBOX_ACCESSED
        )

        options = { meta: resource.metadata, links: }
        render json: Mobile::V0::MessagesSerializer.new(resource.data, options)
      end

      def show
        message_id = params[:id].try(:to_i)
        response = client.get_message(message_id)
        raise Common::Exceptions::RecordNotFound, message_id if response.blank?

        user_triage_teams = client.get_all_triage_teams(@current_user.uuid, use_cache?)
        active_teams = user_triage_teams.data.reject(&:blocked_status)
        user_in_triage_team = active_teams.any? do |team|
          response.triage_group_name && team.name == response.triage_group_name
        end

        meta = response.metadata.merge(user_in_triage_team:)
        options = { meta: }
        options[:include] = [:attachments] if response.attachment
        render json: Mobile::V0::MessageSerializer.new(response, options)
      end

      def create
        message = Message.new(message_params.merge(upload_params))
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params[:id] = message_params.delete(:draft_id) if message_params[:draft_id].present?
        create_message_params = { message: message_params.to_h }.merge(upload_params)
        Rails.logger.info('Mobile SM Category Tracking', category: create_message_params.dig(:message, :category))

        client_response = build_create_client_response(message, create_message_params)

        # Log unique user event for message sent (with facility tracking if recipient has a station number)
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
          event_facility_ids: Array(recipient_facility_id)
        )

        options = { meta: {} }
        options[:include] = [:attachments] if client_response.attachment
        render json: Mobile::V0::MessageSerializer.new(client_response, options)
      end

      def destroy
        client.delete_message(params[:id])
        head :no_content
      end

      def thread
        message_id = params[:id].try(:to_i)
        resource = client.get_message_history(message_id)
        raise Common::Exceptions::RecordNotFound, message_id if resource.blank?

        resource.metadata.merge!(message_counts(resource))

        render json: Mobile::V0::MessagesSerializer.new(resource.data, { meta: resource.metadata })
      end

      def reply
        message = Message.new(message_params.merge(upload_params)).as_reply
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params[:id] = message_params.delete(:draft_id) if message_params[:draft_id].present?
        create_message_params = { message: message_params.to_h }.merge(upload_params)

        client_response = build_reply_client_response(message, create_message_params)

        # Log unique user event for message sent (with facility tracking if recipient has a station number)
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
          event_facility_ids: Array(recipient_facility_id)
        )

        options = {}
        options[:include] = [:attachments] if client_response.attachment
        render json: Mobile::V0::MessageSerializer.new(client_response, options), status: :created
      end

      def categories
        resource = client.get_categories

        render json: Mobile::V0::CategorySerializer.new(resource)
      end

      def move
        folder_id = params.require(:folder_id)
        client.post_move_message(params[:id], folder_id)
        head :no_content
      end

      def signature
        result = client.get_signature[:data]
        result = { signature_name: nil, include_signature: false, signature_title: nil } if result.nil?
        render json: Mobile::V0::MessageSignatureSerializer.new(@current_user.uuid, result).to_json
      end

      private

      # When we get message parameters as part of a multipart payload (i.e. with attachments),
      # ActionController::Parameters leaves the message part as a string so we have to turn it into
      # an object
      def message_params
        @message_params ||= begin
          params[:message] = JSON.parse(params[:message]) if params[:message].is_a?(String)
          params.require(:message).permit(:draft_id, :category, :body, :recipient_id, :subject, :is_oh_triage_group,
                                          :station_number)
        end
      rescue JSON::ParserError
        raise Common::Exceptions::InvalidFieldValue.new('message', params[:message])
      end

      def upload_params
        @upload_params ||= { uploads: params[:uploads] }
      end

      def oh_triage_group?
        # Check top-level params first (query param or form field),
        # then check inside parsed message JSON (for multipart requests where mobile app
        # includes is_oh_triage_group inside the stringified message JSON)
        value = params[:is_oh_triage_group]
        value ||= message_params[:is_oh_triage_group] if message_params.key?(:is_oh_triage_group)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def build_create_client_response(message, create_message_params)
        return client.post_create_message(message_params.to_h, is_oh: oh_triage_group?) if message.uploads.blank?

        client.post_create_message_with_attachment(create_message_params, is_oh: oh_triage_group?)
      rescue Common::Client::Errors::Serialization => e
        Rails.logger.info('Mobile SM create with attachment error', status: e&.status,
                                                                    error_body: e&.body,
                                                                    message: e&.message)
        raise e
      end

      def build_reply_client_response(message, create_message_params)
        if message.uploads.blank?
          return client.post_create_message_reply(params[:id], message_params.to_h, is_oh: oh_triage_group?)
        end

        client.post_create_message_reply_with_attachment(params[:id], create_message_params, is_oh: oh_triage_group?)
      rescue Common::Client::Errors::Serialization => e
        Rails.logger.info('Mobile SM reply with attachment error', status: e&.status,
                                                                   error_body: e&.body,
                                                                   message: e&.message)
        raise e
      end

      def message_counts(resource)
        {
          message_counts: resource.data.each_with_object(Hash.new(0)) do |obj, hash|
            if obj.try(:read_receipt)
              hash[:read] += 1
            else
              hash[:unread] += 1
            end
          end
        }
      end

      def total_entries(count)
        {
          pagination: {
            total_entries: count
          }
        }
      end

      def extend_timeout
        request.env['rack-timeout.timeout'] = Settings.mhv.sm.timeout
      end

      # Retrieves the facility ID from the station_number parameter provided by the frontend.
      # Used for tracking unique user metrics (UUM) for Oracle Health facility messages.
      # The station_number is optional - if not provided, facility tracking is skipped.
      #
      # @return [String, nil] The station number if provided, or nil if not provided.
      def recipient_facility_id
        message_params[:station_number]&.to_s&.presence
      end

      def validate_message_id
        raise Common::Exceptions::ParameterMissing, 'id' if params[:id].blank?
      end
    end
  end
end
