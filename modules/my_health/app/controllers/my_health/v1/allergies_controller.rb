# frozen_string_literal: true

module MyHealth
  module V1
    class AllergiesController < MrController
      def index
        render_resource client.list_allergies
      end

      def show
        allergy_id = params[:id].try(:strip)
        render_resource client.get_allergy(allergy_id)
      end
    end
  end
end
