# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def accept
        # NOTE: the below is a placeholder for the acceptance logic
        # id = params[:proc_id]
        render json: { message: 'Accepted' }, status: :ok
      end

      def decline
        # NOTE: the below is a placeholder for the deny logic
        # id = params[:proc_id]
        render json: { message: 'Declined' }, status: :ok
      end

      def index
        poa_codes = permitted_params[:poa_codes]&.split(',') || []

        return render json: { error: 'POA codes are required' }, status: :bad_request if poa_codes.blank?

        poa_requests = AccreditedRepresentativePortal::Services::FetchPoaRequests.new(poa_codes).call

        render json: { records: poa_requests, records_count: poa_requests.count }, status: :ok
      end

      private

      def permitted_params
        params.permit(:poa_codes)
      end
    end
  end
end
