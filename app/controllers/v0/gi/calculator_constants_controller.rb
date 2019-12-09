# frozen_string_literal: true

module V0
  module GI
    class CalculatorConstantsController < GIController
      def index
        render json: gi_response_body("get_calculator_constants", scrubbed_params)
      end
    end
  end
end
