# frozen_string_literal: true

require 'unique_user_events'

module MyHealth
  module V1
    class ThreadsController < SMController
      include Vets::SharedLogging

      STATSD_KEY_PREFIX = 'api.my_health.threads'

      def index
        resource = fetch_folder_threads
        raise Common::Exceptions::RecordNotFound, params[:folder_id] if resource.blank?

        # Log unique user event for inbox accessed
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_INBOX_ACCESSED
        )

        options = { meta: resource.metadata }
        render json: ThreadsSerializer.new(resource.data, options)
      end

      def move
        folder_id = params.require(:folder_id)
        client.post_move_thread(params[:id], folder_id)
        head :no_content
      end

      private

      def fetch_folder_threads
        options = {
          page_size: params[:page_size],
          page_number: params[:page_number],
          sort_field: params[:sort_field],
          sort_order: params[:sort_order]
        }
        client.get_folder_threads(params[:folder_id].to_s, options)
      rescue => e
        handle_error(e)
      end

      def handle_error(e)
        error = e.try(:errors).try(:first)
        if error&.status.to_i == 400 && error.detail == 'No messages in the requested folder'
          log_exception_to_rails(error, 'info')
          return Common::Collection.new(
            MessageThread, data: []
          )
        end
        log_exception_to_rails(e)
        StatsD.increment("#{STATSD_KEY_PREFIX}.fail")
        raise e
      end
    end
  end
end
