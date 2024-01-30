# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::VerificationsController < Vye::V1::ApplicationController
      include Pundit::Authorization
      service_tag 'vye'

      skip_before_action :authenticate, if: -> { ivr_key? }

      def create
        authorize user_info, policy_class: Vye::UserInfoPolicy

        user_info.awards.each do |award|
          user_info.verifications.create!(create_params.merge(award:))
        end
      end

      private

      def create_params
        params.permit(%i[
                        change_flag rpo_code rpo_flag act_begin act_end source_ind
                      ])
      end

      def ivr_params
        params.permit(%i[
                        ivr_key ssn
                      ])
      end

      def ivr_key?
        ivr_params[:ivr_key].present? && ivr_params[:ivr_key] == Settings.vye.ivr_key
      end

      def load_user_info
        case ivr_key?
        when true
          @user_info = Vye::UserInfo.find_from_digested_ssn(ivr_params[:ssn])
        else
          super
        end
      end
    end
  end
end
