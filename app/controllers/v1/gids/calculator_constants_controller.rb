# frozen_string_literal: true

module V1
  module GIDS
    class CalculatorConstantsController < GIDSController
      def index
        render json: service.get_calculator_constants_v1(scrubbed_params)
      end
    end
  end
end
