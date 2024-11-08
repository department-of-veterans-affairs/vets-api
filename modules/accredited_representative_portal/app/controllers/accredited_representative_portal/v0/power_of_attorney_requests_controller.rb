# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      #TODO: address authorization
      
      def show
        poa_request_details_id = params[:id]
        poa_request_details_service = PoaRequestDetailsService.new(poa_request_details_id)
        render json: poa_request_details_service.call
      end
    end
  end
end