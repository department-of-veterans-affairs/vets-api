# frozen_string_literal: true

module V1
  module GIDS
    class LceController < GIDSController
      def index
        render json: service.get_lce_search_results_v1(scrubbed_params)
      end
    end
  end
end
