# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::VerificationsController < Vye::V1::ApplicationController
      include Pundit::Authorization

      service_tag 'vye'

      skip_before_action :authenticate, if: -> { ivr_key? }

      def create
        authorize user_info, policy_class: UserInfoPolicy

        user_info.verifications.create!(source_ind:)
      end

      private

      def source_ind
        ivr_key? ? :phone : :web
      end

      def ivr_params
        params.permit(%i[ivr_key ssn])
      end

      def ivr_key?
        ivr_params[:ivr_key].present? && ivr_params[:ivr_key] == Settings.vye.ivr_key
      end

      def load_user_info
        case ivr_key?
        when true
          @user_info = Vye::UserProfile.find_from_digested_ssn(ivr_params[:ssn])&.active_user_info
        else
          super
        end
      end
    end
  end
end
