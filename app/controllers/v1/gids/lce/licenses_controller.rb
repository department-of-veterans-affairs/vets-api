# frozen_string_literal: true

module V1
  module GIDS
    module Lce
      class LicensesController < LceController
        def show
          render json: service.get_license_details_v1(scrubbed_params)
        end
      end
    end
  end
end
