# frozen_string_literal: true

module V1
  module Lorota
    class Token < BasicToken
      def initialize(opts)
        @settings = Settings.check_in.lorota_v1
        @check_in = opts[:check_in]
        @claims_token = ClaimsToken.build(check_in: check_in).sign_assertion
        @request = Request.build(claims_token: claims_token)
      end

      def fetch
        resp = request.post("/#{base_path}/token", auth_params)

        self.access_token = Oj.load(resp.body)&.fetch('token')
        self
      end

      def auth_params
        {
          SSN4: check_in.last4,
          lastName: check_in.last_name
        }
      end
    end
  end
end
