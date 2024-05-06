# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::VerificationsController < Vye::V1::ApplicationController
      include Pundit::Authorization

      service_tag 'vye'

      skip_before_action :authenticate, if: -> { ivr_key? }

      def create
        authorize user_info, policy_class: UserInfoPolicy

        award = user_info.awards.first
        user_profile = user_info.user_profile
        Verification.create!(source_ind:, award:, user_profile:)
      end

      private

      def source_ind
        ivr_key? ? :phone : :web
      end

      def ivr_params
        params.permit(%i[ivr_key file_number])
      end

      def ivr_key?
        ivr_params[:ivr_key].present? && ivr_params[:ivr_key] == Vye.settings.ivr_key
      end

      def load_user_info
        case ivr_key?
        when true
          @user_info = Vye::UserProfile.find_from_digested_file_number(ivr_params[:file_number])&.active_user_info
        else
          super
        end
      end
    end
  end
end
