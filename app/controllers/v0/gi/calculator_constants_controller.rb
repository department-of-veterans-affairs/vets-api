# frozen_string_literal: true

module V0
  module GI
    class CalculatorConstantsController < GIController
      def index
        render json: client.get_calculator_constants(scrubbed_params)
      end
    end
  end
end
