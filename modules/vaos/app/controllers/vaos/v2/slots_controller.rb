# frozen_string_literal: true

module VAOS
  module V2
    class SlotsController < VAOS::BaseController
      def index
        response = systems_service.get_available_slots(location_id:,
                                                       clinic_id:,
                                                       clinical_service: nil,
                                                       start_dt:,
                                                       end_dt:)
        render json: VAOS::V2::SlotsSerializer.new(response)
      end

      def facility_slots
        if !params[:clinic_id] && !params[:clinical_service]
          render status: :bad_request, json: {
            errors: [
              {
                status: 400,
                detail: 'clinic_id or clinical_service is required.'
              }
            ]
          }

        else
          response = systems_service.get_available_slots(location_id:,
                                                         clinic_id: params[:clinic_id],
                                                         clinical_service: params[:clinical_service],
                                                         start_dt:,
                                                         end_dt:)
          render json: VAOS::V2::SlotsSerializer.new(response)
        end
      end

      def provider_slots
        if params[:clinical_service]
          response = systems_service.get_available_slots(location_id:,
                                                         provider_id:,
                                                         clinical_service: params[:clinical_service],
                                                         start_dt:,
                                                         end_dt:)
          render json: VAOS::V2::SlotsSerializer.new(response)
        else
          render status: :bad_request, json: {
            errors: [
              {
                status: 400,
                detail: 'clinical_service is required.'
              }
            ]
          }

        end
      end

      private

      def systems_service
        VAOS::V2::SystemsService.new(current_user)
      end

      def location_id
        params.require(:location_id)
      end

      def clinic_id
        params.require(:clinic_id)
      end

      def provider_id
        params.require(:provider_id)
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
