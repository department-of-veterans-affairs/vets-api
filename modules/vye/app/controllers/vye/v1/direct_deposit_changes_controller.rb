# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::DirectDepositChangesController < Vye::V1::ApplicationController
      include Pundit::Authorization

      service_tag 'verify-your-enrollment'

      before_action :convert_params_camel_case_to_snake_case

      def create
        authorize user_info, policy_class: Vye::UserInfoPolicy

        user_info.direct_deposit_changes.create!(create_params)
      end

      private

      def create_params
        params
          .permit(
            %i[full_name phone email acct_no acct_type routing_no bank_name bank_phone]
          )
      end

      def convert_params_camel_case_to_snake_case
        request.parameters.deep_transform_keys!(&:underscore)
      end
    end
  end
end
