# frozen_string_literal: true

module V1
  module GIDS
    class ZipcodeRatesController < GIDSController
      def show
        render json: service.get_zipcode_rate_v1(scrubbed_params)
      end
    end
  end
end
