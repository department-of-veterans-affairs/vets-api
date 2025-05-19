# frozen_string_literal: true

module Vye
  module V1
    class AddressChangesController < Vye::V1::ApplicationController
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
    end
  end
end
