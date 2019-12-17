# frozen_string_literal: true

module V0
  module Gids
    class ZipcodeRatesController < GidsController
      def show
        render json: service.get_zipcode_rate(scrubbed_params)
      end
    end
  end
end
