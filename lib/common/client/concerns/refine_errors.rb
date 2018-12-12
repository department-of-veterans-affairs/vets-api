# frozen_string_literal: true

module Common::Client
  module Concerns
    module RefineErrors
      def handle_service_unavailable
        yield
      rescue Common::Exceptions::BackendServiceException => e
        raise Common::Exceptions::ServiceUnavailable if e.original_status&.to_i == 503

        raise
      rescue Common::Client::Errors::HTTPError => e
        raise Common::Exceptions::ServiceUnavailable if e.status&.to_i == 503

        raise
      end
    end
  end
end
