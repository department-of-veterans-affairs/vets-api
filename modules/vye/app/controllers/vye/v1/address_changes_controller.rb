# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::AddressChangesController < Vye::V1::ApplicationController
      include Pundit::Authorization

      service_tag 'verify-your-enrollment'

      before_action :convert_params_camel_case_to_snake_case

      def create
        authorize user_info, policy_class: Vye::UserInfoPolicy

        user_info.address_changes.create!(create_params.merge(origin: 'frontend'))
      end

      private

      def create_params
        params
          .permit(
            %i[veteran_name address1 address2 address3 address4 city state zip_code]
          )
      end

      def convert_params_camel_case_to_snake_case
        request.parameters.deep_transform_keys!(&:underscore)
      end
    end
  end
end
