# frozen_string_literal: true

module V0
  module GI
    class ZipcodeRatesController < GIController
      def show
        render json: client.get_zipcode_rate(scrubbed_params)
      end
    end
  end
end
