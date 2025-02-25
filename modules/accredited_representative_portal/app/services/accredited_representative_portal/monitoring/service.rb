# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Monitoring
    class Service
      NAME = 'accredited-representative-portal'

      def initialize(service = NAME, user_context: nil, default_tags: [])
        @service = service
        @user_context = user_context
        @logger = ::Logging::Monitor.new(service)
        @default_tags = default_tags
      end

      def track_request(message: nil, metric: Metric::POA, tags: [])
        message ||= 'Request recorded'
        @logger.track(:info, message, metric, tags: merge_tags(tags))
      end

      def track_error(message:, metric: Metric::POA, error: StandardError, tags: [])
        error_instance = error.is_a?(Class) ? error.new(message) : error
        error_tags = tags + [Tag::Level::ERROR, error_type_tag(error_instance)]

        @logger.track(:error, message, metric, tags: merge_tags(error_tags))
      end

      private

      def merge_tags(tags)
        (tags + default_service_tags).uniq
      end

      def error_type_tag(error)
        return Tag::Error::VALIDATION if error.is_a?(::ActiveRecord::RecordInvalid)
        return Tag::Error::TIMEOUT if error.is_a?(::Timeout::Error)
        if error.is_a?(ActionController::BadRequest) || error.is_a?(ActionController::RoutingError)
          return Tag::Error::HTTP_CLIENT
        end
        return Tag::Error::NOT_FOUND if error.is_a?(ActiveRecord::RecordNotFound)

        Tag::Error::HTTP_SERVER # Default to server error for unexpected exceptions
      end

      def default_service_tags
        [@default_tags, "service:#{@service}"].flatten.compact
      end
    end
  end
end
