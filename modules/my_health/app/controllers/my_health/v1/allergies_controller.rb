# frozen_string_literal: true

module MyHealth
  module V1
    class AllergiesController < MrController
      def index
        resource = client.list_allergies
        render json: resource.to_json
      end

      def show
        allergy_id = params[:id].try(:to_i)
        resource = client.get_allergy(allergy_id)
        render json: resource.to_json
      end
    end
  end
end
