# frozen_string_literal: true

module Mobile
  module V1
    class MessagesController < MessagingController
      def thread
        message_id = params[:id]
        resource = client.get_messages_for_thread(message_id)
        raise Common::Exceptions::RecordNotFound, message_id if resource.blank?

        resource.data = resource.data.filter { |m| m.message_id.to_s != params[:id] } if params[:excludeProvidedMessage]
        resource.metadata.merge!(message_counts(resource))

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: Mobile::V1::MessagesSerializer,
               meta: resource.metadata
      end

      private

      def message_counts(resource)
        {
          message_counts: resource.attributes.each_with_object(Hash.new(0)) do |obj, hash|
            hash[:read] += 1 if obj[:read_receipt]
            hash[:unread] += 1 unless obj[:read_receipt]
          end
        }
      end
    end
  end
end
