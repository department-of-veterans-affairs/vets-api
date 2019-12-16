# frozen_string_literal: true

module V0
  module Gids
    class ZipcodeRatesController < GidsController
      def show
        render json: gi_response_body(:get_zipcode_rate, scrubbed_params)
      end
    end
  end
end
