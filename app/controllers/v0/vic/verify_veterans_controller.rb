module V0
  module VIC
    class VerifyVeteransController < ApplicationController
      skip_before_action(:authenticate)

      def create
        render(
          json: {
            verified: ::VIC::VerifyVeteran.send_request(params[:veteran])
          }
        )
      end
    end
  end
end
