# frozen_string_literal: true

require 'bgs/service'

module V0
  module Profile
    class Ch33BankAccountsController < ApplicationController
      before_action { authorize :ch33_dd, :access? }

      def index
        render(
          json: service.get_ch33_dd_eft_info,
          serializer: Ch33BankAccountSerializer
        )
      end

      def update
        render(
          json: service.update_ch33_dd_eft(
            params[:financial_institution_routing_number],
            params[:account_number],
            params[:account_type] == 'Checking'
          )
        )
      end

      private

      def service
        BGS::Service.new(current_user)
      end
    end
  end
end
