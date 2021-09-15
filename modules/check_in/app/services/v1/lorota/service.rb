# frozen_string_literal: true

module V1
  module Lorota
    class Service < BasicService
      def initialize(opts)
        @settings = Settings.check_in.lorota_v1
        @check_in = opts[:check_in]
        @session = Session.build(check_in: check_in)
        @request = Request.build(token: session.from_redis)
        @response = Response
      end

      def permissions
        'read.full'
      end
    end
  end
end
