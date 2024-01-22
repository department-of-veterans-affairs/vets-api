# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::DirectDepositChangesController < Vye::V1::ApplicationController
      include Pundit::Authorization
      service_tag 'vye'

      def create
        authorize user_info, policy_class: Vye::UserInfoPolicy

        user_info.direct_deposit_changes.create!(create_params)
      end

      private

      def create_params
        params.permit(%i[
                        rpo ben_type full_name phone phone2 email acct_no
                        acct_type routing_no chk_digit bank_name bank_phone
                      ])
      end
    end
  end
end
