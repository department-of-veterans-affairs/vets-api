# frozen_string_literal: true

module AccreditedRepresentatives
  # We are duplicating some functionality from `::ApplicationController`
  # because inheriting it would import inappropriate functionality, around
  # authentication for instance. Maybe we can find a refactor that gives us
  # better reuse. For now, we can try and tag the duplicative code to help us
  # deal with things later.
  #
  # TODO: address code tagged with <duplicates-application-controller>
  class DuplicativeApplicationController < ActionController::API
    # <duplicates-application-controller>
    include Traceable

    # <duplicates-application-controller>
    concerning :ExceptionHandling do
      included do
        rescue_from Exception do |ex|
          exception =
            case ex
            when Common::Exceptions::BaseError
              ex
            else
              # TODO: test this codepath
              Common::Exceptions::InternalServerError.new(ex)
            end

          render(
            json: { errors: exception.errors },
            status: exception.status_code
          )
        end
      end
    end

    # <duplicates-application-controller>
    def routing_error
      raise Common::Exceptions::RoutingError, params[:path]
    end
  end
end
