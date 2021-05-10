# frozen_string_literal: true

module V0
  module GIDS
    class ZipcodeRatesController < GIDSController
      def show
        render json: service.get_zipcode_rate_v0(scrubbed_params)
      end
    end
  end
end
