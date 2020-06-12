# frozen_string_literal: true

require_relative 'base'

module CARMA
  module Models
    class Caregiver < Base
      request_payload_key :icn

      attr_accessor :icn

      def initialize(args = {})
        @icn = args[:icn]
      end
    end
  end
end
