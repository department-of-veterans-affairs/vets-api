# frozen_string_literal: true

module Mobile
  module V0
    class MessagesController < MessagingController
      include Filterable

      def index
        resource = client.get_folder_messages(@current_user.uuid, params[:folder_id].to_s, use_cache?)
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        resource = resource.find_by(filter_params) if params[:filter].present?
        resource = resource.sort(params[:sort])

        links = pagination_links(resource)
        resource = resource.paginate(**pagination_params)
        resource.metadata.merge!(message_counts(resource))

        options = { meta: resource.metadata, links: }
        render json: Mobile::V0::MessagesSerializer.new(resource.data, options)
      end

      def show
        message_id = params[:id].try(:to_i)
        response = client.get_message(message_id)

        raise Common::Exceptions::RecordNotFound, message_id if response.blank?

        user_triage_teams = client.get_triage_teams(@current_user.uuid, use_cache?)
        user_in_triage_team = user_triage_teams.data.any? { |team| team.name == response.triage_group_name }

        meta = response.metadata.merge(user_in_triage_team?: user_in_triage_team)
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

        client_response = if message.uploads.present?
                            begin
                              client.post_create_message_with_attachment(create_message_params)
                            rescue Common::Client::Errors::Serialization => e
                              Rails.logger.info('Mobile SM create with attachment error', status: e&.status,
                                                                                          error_body: e&.body,
                                                                                          message: e&.message)
                              raise e
                            end
                          else
                            client.post_create_message(message_params.to_h)
                          end

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

        client_response = if message.uploads.present?
                            client.post_create_message_reply_with_attachment(params[:id], create_message_params)
                          else
                            client.post_create_message_reply(params[:id], message_params.to_h)
                          end

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
          params.require(:message).permit(:draft_id, :category, :body, :recipient_id, :subject)
        end
      end

      def upload_params
        @upload_params ||= { uploads: params[:uploads] }
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
    end
  end
end
