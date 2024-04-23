# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      def accept
        id = params[:proc_id]
        result = update_poa_request(id, 'Accepted')

        if result[:success]
          render json: { message: 'Accepted' }, status: :ok
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      end

      def decline
        id = params[:proc_id]
        result = update_poa_request(id, 'Declined')

        if result[:success]
          render json: { message: 'Declined' }, status: :ok
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end
      end

      def index
        poa_codes = permitted_params[:poa_codes]&.split(',') || []

        return render json: { error: 'POA codes are required' }, status: :bad_request if poa_codes.blank?

        poa_requests = AccreditedRepresentativePortal::Services::FetchPoaRequests.new(poa_codes).call

        render json: { records: poa_requests['records'], records_count: poa_requests['meta']['totalRecords'].to_i },
               status: :ok
      end

      private

      def permitted_params
        params.permit(:poa_codes)
      end

      # TODO: This class is slated for update to use the Lighthouse API once the appropriate endpoint
      # is available. For more information on the transition plan, refer to:
      # https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/80195
      def update_poa_request(proc_id, action)
        # TODO: Update the below to use the RepresentativeUser's profile data
        # representative = {
        #   first_name: 'John',
        #   last_name: 'Doe'
        # }

        # Simulating the interaction with an external service to update POA.
        # In real implementation, this method will make an actual API call.
        # service_response = ClaimsApi::ManageRepresentativeService.new.update_poa_request(
        #   representative:,
        #   proc_id:
        # )

        if %w[Accepted Declined].include?(action)
          {
            success: true,
            response: {
              proc_id:,
              action:,
              status: 'updated',
              dateRequestActioned: Time.current.iso8601,
              secondaryStatus: action == 'Accepted' ? 'obsolete' : 'cancelled'
            }
          }
        else
          { success: false, error: 'Invalid action' }
        end
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
