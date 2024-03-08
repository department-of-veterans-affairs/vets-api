# frozen_string_literal: true

require 'logging/third_party_transaction'
# --- Accredited Representatives User Controller ---
# This controller handles user-related actions specifically for the context of
# accredited representatives. It is currently a copy of app/controllers/v0/users_controller.rb and
# will be modified to support representative-specific functionality.
#
# **Important:**  Reference the ZenHub issue for detailed context and changes:
#  https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/75746
module AccreditedRepresentatives
  module V0
    class UsersController < ApplicationController
      service_tag 'accredited-representatives' # NOTE: this was service_tag 'identity' in the original file

      def show
        pre_serialized_profile = Users::Profile.new(current_user, @session_object).pre_serialize

        render(
          json: pre_serialized_profile,
          status: pre_serialized_profile.status,
          serializer: UserSerializer,
          meta: { errors: pre_serialized_profile.errors }
        )
      end

      def icn
        render json: { icn: current_user.icn }, status: :ok
      end
    end
  end
end
