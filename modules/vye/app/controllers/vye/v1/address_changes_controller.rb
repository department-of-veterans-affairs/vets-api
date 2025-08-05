# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::AddressChangesController < Vye::V1::ApplicationController
      def create
        authorize user_info, policy_class: Vye::UserInfoPolicy

        if Flipper.enabled?(:disable_bdn_processing)
          Rails.logger.warn("DISABLE BDN PROCESSING: received unexpected call to AddressChangesController, UserInfo ID: #{user_info&.id}") # rubocop:disable Layout/LineLength
          render json: {}, status: :bad_request
          return
        end

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
