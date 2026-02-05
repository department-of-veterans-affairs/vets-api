# frozen_string_literal: true

require 'unique_user_events'

module MyHealth
  module V1
    class MessagesController < SMController
      MAX_STANDARD_FILES = 4

      before_action :extend_timeout, only: %i[create reply], if: :oh_triage_group?

      def show
        message_id = params[:id].try(:to_i)
        response = client.get_message(message_id)

        raise Common::Exceptions::RecordNotFound, message_id if response.blank?

        options = { meta: response.metadata }
        render json: MessageSerializer.new(response, options)
      end

      def create
        message = Message.new(message_params.merge(upload_params)
                  .merge(is_large_attachment_upload: use_large_attachment_upload))
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params_h = prepare_message_params_h
        create_message_params = { message: message_params_h }.merge(upload_params)
        client_response = create_client_response(message, message_params_h, create_message_params)

        # Log unique user event for message sent (with facility tracking if recipient has a station number)
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
          event_facility_ids: Array(recipient_facility_id)
        )

        options = build_response_options(client_response)
        render json: MessageSerializer.new(client_response, options)
      end

      def destroy
        client.delete_message(params[:id])
        head :no_content
      end

      def thread
        message_id = params[:id].try(:to_i)
        resource = if params[:full_body] == 'true'
                     # returns full body of message including attachments attributes
                     client.get_full_messages_for_thread(message_id)
                   else
                     client.get_messages_for_thread(message_id)
                   end
        raise Common::Exceptions::RecordNotFound, message_id if resource.blank?

        options = { meta: resource.metadata, is_collection: true }
        render json: MessageDetailsSerializer.new(resource.data, options)
      end

      def reply
        Rails.logger.info("MHV SM: Replying to message, large attachment upload: #{use_large_attachment_upload}")
        message = Message.new(message_params.merge(upload_params)
          .merge(is_large_attachment_upload: use_large_attachment_upload)).as_reply
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        message_params_h = prepare_message_params_h
        create_message_params = { message: message_params_h }.merge(upload_params)
        client_response = reply_client_response(message, message_params_h, create_message_params)

        # Log unique user event for message sent (with facility tracking if recipient has a station number)
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
          event_facility_ids: Array(recipient_facility_id)
        )

        options = build_response_options(client_response)
        render json: MessageSerializer.new(client_response, options), status: :created
      end

      def categories
        resource = client.get_categories

        render json: CategorySerializer.new(resource)
      end

      def signature
        resource = client.get_signature
        if resource[:data].nil?
          resource[:data] =
            { signature_name: nil, include_signature: false, signature_title: nil }
        end
        # see MessageSignatureSerializer for more information
        render json: resource
      end

      def move
        folder_id = params.require(:folder_id)
        client.post_move_message(params[:id], folder_id)
        head :no_content
      end

      private

      def prepare_message_params_h
        message_params_h = message_params.to_h
        message_params_h[:id] = message_params_h.delete(:draft_id) if message_params_h[:draft_id].present?
        message_params_h
      end

      def build_response_options(client_response)
        options = { meta: {} }
        options[:include] = [:attachments] if client_response.attachment
        options
      end

      def create_client_response(message, message_params_h, create_message_params)
        return client.post_create_message(message_params_h, is_oh: oh_triage_group?) if message.uploads.blank?

        if use_large_attachment_upload
          Rails.logger.info('MHV SM: Using large attachments endpoint')
          client.post_create_message_with_lg_attachments(create_message_params, is_oh: oh_triage_group?)
        else
          Rails.logger.info('MHV SM: Using standard attachments endpoint')
          client.post_create_message_with_attachment(create_message_params, is_oh: oh_triage_group?)
        end
      end

      def reply_client_response(message, message_params_h, create_message_params)
        if message.uploads.blank?
          return client.post_create_message_reply(params[:id], message_params_h, is_oh: oh_triage_group?)
        end

        if use_large_attachment_upload
          Rails.logger.info('MHV SM: Using large attachments endpoint - reply')
          client.post_create_message_reply_with_lg_attachment(params[:id], create_message_params,
                                                              is_oh: oh_triage_group?)
        else
          Rails.logger.info('MHV SM: Using standard attachments endpoint - reply')
          client.post_create_message_reply_with_attachment(params[:id], create_message_params,
                                                           is_oh: oh_triage_group?)
        end
      end

      def message_params
        @message_params ||= begin
          params[:message] = JSON.parse(params[:message]) if params[:message].is_a?(String)
          params.require(:message).permit(:draft_id, :category, :body, :recipient_id, :subject, :station_number)
        end
      end

      def upload_params
        @upload_params ||= { uploads: params[:uploads] }
      end

      def oh_triage_group?
        ActiveModel::Type::Boolean.new.cast(params[:is_oh_triage_group])
      end

      def any_file_too_large
        Array(upload_params[:uploads]).any? { |upload| upload.size > 6.megabytes }
      end

      def total_size_too_large
        Array(upload_params[:uploads]).sum(&:size) > 10.megabytes
      end

      def total_file_count_too_large
        Array(upload_params[:uploads]).size > MAX_STANDARD_FILES
      end

      def use_large_attachment_upload
        return false unless any_file_too_large || total_size_too_large || total_file_count_too_large

        Flipper.enabled?(:mhv_secure_messaging_large_attachments) ||
          (Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, current_user) && oh_triage_group?)
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
    end
  end
end
