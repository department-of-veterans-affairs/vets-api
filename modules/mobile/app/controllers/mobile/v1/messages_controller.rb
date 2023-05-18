# frozen_string_literal: true

module Mobile
  module V1
    class MessagesController < MessagingController
      def thread
        message_id = params[:id].try(:to_i)
        resource = client.get_messages_for_thread(message_id)
        raise Common::Exceptions::RecordNotFound, message_id if resource.blank?

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: Mobile::V0::MessagesSerializer,
               meta: resource.metadata
      end
    end
  end
end
