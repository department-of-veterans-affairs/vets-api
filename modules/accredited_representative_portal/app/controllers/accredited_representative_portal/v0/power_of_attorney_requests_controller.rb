# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController

      # TODO: When the pilot begins rolling out we need to uncomment this
      # before_action :verify_pilot_enabled

      def accept
        # TODO: The ID will be either a veteran_id or a poa_id
        # id = params[:id]
        # NOTE: the below is a placeholder for the acceptance logic
        render json: { message: 'Accepted' }, status: :ok
      end

      def decline
        # TODO: The ID will be either a veteran_id or a poa_id
        # id = params[:id]
        # NOTE: the below is a placeholder for the deny logic
        render json: { message: 'Declined' }, status: :ok
      end
    end
  end
end
