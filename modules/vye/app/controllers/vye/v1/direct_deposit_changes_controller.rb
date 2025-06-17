# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::DirectDepositChangesController < Vye::V1::ApplicationController
      def create
        authorize user_info, policy_class: Vye::UserInfoPolicy

        if Flipper.enabled?(:disable_bdn_processing)
          Rails.logger.warn("DISABLE BDN PROCESSING: received unexpected call to DirectDepositChangesController, UserInfo ID: #{user_info&.id}") # rubocop:disable Layout/LineLength
          render json: {}, status: :bad_request
          return
        end

        user_info.direct_deposit_changes.create!(create_params)
      end

      private

      def create_params
        params
          .permit(
            %i[full_name phone email acct_no acct_type routing_no bank_name bank_phone]
          )
      end
    end
  end
end
