# frozen_string_literal: true

module V1
  module GIDS
    module Lce
      class PrepsController < LceController
        def show
          render json: service.get_prep_details_v1(scrubbed_params)
        end
      end
    end
  end
end
