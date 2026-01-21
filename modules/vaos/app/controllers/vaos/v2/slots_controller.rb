# frozen_string_literal: true

module VAOS
  module V2
    class SlotsController < VAOS::BaseController
      def index
        response = systems_service.get_available_slots({
                                                         location_id:,
                                                         clinic_id:,
                                                         clinical_service: nil,
                                                         provider_id: nil,
                                                         start_dt:,
                                                         end_dt:
                                                       })
        render json: VAOS::V2::SlotsSerializer.new(response)
      end

      def facility_slots
        if (error = facility_slots_bad_request(params))
          render status: :bad_request, json: { errors: [{ status: 400, detail: error }] }
        else
          response = systems_service.get_available_slots({
                                                           location_id:,
                                                           clinic_id:,
                                                           clinical_service:,
                                                           provider_id:,
                                                           start_dt:,
                                                           end_dt:
                                                         })
          render json: VAOS::V2::SlotsSerializer.new(response)
        end
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def facility_slots_bad_request(params)
        # If provider_id is passed, clinical_service is also required
        if params[:provider_id]
          return 'provider_id and clinical_service is required.' unless params[:clinical_service]

        # If provider_id is NOT passed, clinical_service OR clinic_id is required
        elsif !params[:clinic_id] && !params[:clinical_service]
          return 'clinic_id or clinical_service is required.'
        end

        false
      end

      def location_id
        params.require(:location_id)
      end

      def clinic_id
        params[:clinic_id]
      end

      def provider_id
        params[:provider_id]
      end

      def clinical_service
        params[:clinical_service]
      end

      def start_dt
        params.require(:start)
      end

      def end_dt
        params.require(:end)
      end
    end
  end
end
