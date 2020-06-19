# frozen_string_literal: true

require_relative 'base'

module CARMA
  module Models
    class Veteran < Base
      request_payload_key :icn, :is_veteran

      attr_accessor :icn, :is_veteran

      def initialize(args = {})
        @icn = args[:icn]
        @is_veteran = args[:is_veteran]
      end
    end
  end
end
