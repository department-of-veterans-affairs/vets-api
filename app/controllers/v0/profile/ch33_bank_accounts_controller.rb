# frozen_string_literal: true

require 'bgs/service'

module V0
  module Profile
    class Ch33BankAccountsController < ApplicationController
      before_action { authorize :ch33_dd, :access? }

      def index
        render_find_ch33_dd_eft
      end

      def update
        res = service.update_ch33_dd_eft(
          params[:financial_institution_routing_number],
          params[:account_number],
          params[:account_type] == 'Checking'
        ).body

        unless res[:update_ch33_dd_eft_response][:return][:return_code] == 'S'
          return render(json: res, status: :bad_request)
        end

        render_find_ch33_dd_eft
      end

      private

      def render_find_ch33_dd_eft
        render(
          json: service.find_ch33_dd_eft,
          serializer: Ch33BankAccountSerializer
        )
      end

      def service
        BGS::Service.new(current_user)
      end
    end
  end
end
