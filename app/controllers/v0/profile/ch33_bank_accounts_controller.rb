# frozen_string_literal: true
require 'bgs/service'

module V0
  module Profile
    class Ch33BankAccountsController < ApplicationController
      def index
        render(
          json: service.find_ch33_dd_eft,
          serializer: Ch33BankAccountSerializer
        )
      end

      private

      def service
        BGS::Service.new(current_user)
      end
    end
  end
end
