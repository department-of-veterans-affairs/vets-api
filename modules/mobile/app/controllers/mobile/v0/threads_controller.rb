# frozen_string_literal: true

require 'unique_user_events'

module Mobile
  module V0
    class ThreadsController < MessagingController
      def index
        options = {
          page_size: params[:page_size],
          page_number: params[:page],
          sort_field: params[:sort_field],
          sort_order: params[:sort_order]
        }
        resource = client.get_folder_threads(params[:folder_id].to_s, options)

        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        # Log unique user event for inbox accessed
        UniqueUserEvents.log_event(
          user: @current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_INBOX_ACCESSED
        )

        options = { meta: resource.metadata }
        render json: MyHealth::V1::ThreadsSerializer.new(resource.data, options)
      end
    end
  end
end
