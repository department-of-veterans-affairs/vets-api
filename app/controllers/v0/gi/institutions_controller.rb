# frozen_string_literal: true
module V0
  module GI
    class InstitutionsController < GIController
      def autocomplete
        render json: client.get_autocomplete_suggestions(params[:term])
      end

      def search
        render json: client.get_search_results(search_params)
      end

      def show
        render json: client.get_institution_details(params[:id])
      end

      private

      def search_params
        params.except(:action, :controller, :format)
      end
    end
  end
end
