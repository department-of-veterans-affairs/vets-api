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
        rescue_from ActiveRecord::RecordNotFound do |_e|
          render(
            json: { errors: ['Record not found'] },
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

    def set_poa_request(id)
      @poa_request = policy_scope(PowerOfAttorneyRequest).find(id)
    end
  end
end
