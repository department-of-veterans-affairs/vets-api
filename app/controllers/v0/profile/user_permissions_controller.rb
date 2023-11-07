# frozen_string_literal: true

module V0
  module Profile
    class UserPermissionsController < ApplicationController
      def show
        if Flipper.enabled?(:profile_user_claims, @current_user)
          render status: :ok, json: user_permissions
        else
          render status: :forbidden, json: { error: 'User permissions not enabled.' }
        end
      end

      private

      def user_permissions
        {
          cnp_direct_deposit: LighthousePolicy.new(@current_user).access_disability_compensations?,
          communication_preferences: (Vet360Policy.new(@current_user).access? &&
                                      CommunicationPreferencesPolicy.new(@current_user).access?),
          connected_apps: true,
          edu_direct_deposit: Ch33DdPolicy.new(@current_user).access?,
          military_history: Vet360Policy.new(@current_user).military_access?,
          payment_history: BGSPolicy.new(@current_user).access?(log_stats: false),
          personal_information: MPIPolicy.new(@current_user).queryable?,
          rating_info: LighthousePolicy.new(@current_user).rating_info_access?
        }
      end
    end
  end
end
