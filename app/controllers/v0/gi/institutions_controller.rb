# frozen_string_literal: true
module V0
  module GI
    class InstitutionsController < GIController
      WHITELIST = %w(name page per_page type_name school_type country state
                     student_veteran_group yellow_ribbon_scholarship
                     principles_of_excellence eight_keys_to_veteran_success).freeze

      def autocomplete
        render json: client.get_autocomplete_suggestions(params[:term])
      end

      def search
        render json: client.get_search_results(whitelisted_search_params)
      end

      def show
        render json: client.get_institution_details(params[:id])
      end

      private

      def whitelisted_search_params
        params.select { |k, _v| WHITELIST.include?(k) }
      end
    end
  end
end
