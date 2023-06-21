# frozen_string_literal: true

module MyHealth
  module V1
    class VitalsController < MrController
      def index
        patient_id = params[:patient_id]
        resource = client.list_vitals(patient_id)
        raise Common::Exceptions::InternalServerError if resource.blank?

        render json: resource.to_json
      end
    end
  end
end
