# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PowerOfAttorneyRequests
    extend ActiveSupport::Concern

    ##
    # TODO: We ought to centralize our exception rendering. Starting here for
    # now.
    #
    concerning :ExceptionRendering do
      included do
        rescue_from ActiveRecord::RecordNotFound do |e|
          render(
            json: { errors: [e.message] },
            status: :not_found
          )
        end

        rescue_from ActiveRecord::RecordInvalid do |e|
          render(
            json: { errors: e.record.errors.full_messages },
            status: :unprocessable_entity
          )
        end

        rescue_from ActionController::BadRequest do |e|
          render(
            json: { errors: [e.message] },
            status: :bad_request
          )
        end
      end
    end

    def find_poa_request(id)
      @poa_request = poa_request_scope.find(id)
    end

    def poa_request_scope
      policy_scope(PowerOfAttorneyRequest)
    end
  end
end
