# frozen_string_literal: true

require 'logging/third_party_transaction'

module V0
  class UsersController < ApplicationController
    extend Logging::ThirdPartyTransaction::MethodWrapper

    wrap_with_logging(
      :show,
      additional_class_logs: { action: 'Loading User' },
      additional_instance_logs: { user_uuid: %i[current_user account_uuid] }
    )

    def show
      pre_serialized_profile = Users::Profile.new(current_user, @session_object).pre_serialize

      render(
        json: pre_serialized_profile,
        status: pre_serialized_profile.status,
        serializer: UserSerializer,
        meta: { errors: pre_serialized_profile.errors }
      )
    end
  end
end
