# frozen_string_literal: true

module V0
  module GIDS
    class CalculatorConstantsController < GIDSController
      def index
        render json: service.get_calculator_constants(scrubbed_params)
      end
    end
  end
end
