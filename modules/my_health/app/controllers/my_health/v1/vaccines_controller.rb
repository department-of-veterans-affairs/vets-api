# frozen_string_literal: true

module MyHealth
  module V1
    class VaccinesController < MRController
      def index
        render_resource client.list_vaccines
      end

      def show
        vaccine_id = params[:id].try(:to_i)
        render_resource client.get_vaccine(vaccine_id)
      end
    end
  end
end
