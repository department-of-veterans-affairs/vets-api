# frozen_string_literal: true

module V0
  module Gids
    class CalculatorConstantsController < GidsController
      def index
        render json: gi_response_body(:get_calculator_constants, scrubbed_params)
      end
    end
  end
end
