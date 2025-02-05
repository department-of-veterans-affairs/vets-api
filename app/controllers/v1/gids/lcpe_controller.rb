# frozen_string_literal: true

require 'gi/lcpe/client'

module V1
  module GIDS
    class LCPEController < GIDSController
      private

      def service
        GI::LCPE::Client.new
      end
    end
  end
end
