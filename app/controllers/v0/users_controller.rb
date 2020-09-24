# frozen_string_literal: true

module V0
  class UsersController < ApplicationController
    def show
      pre_serialized_profile = Users::Profile.new(current_user).pre_serialize

      render(
        json: pre_serialized_profile,
        status: pre_serialized_profile.status,
        serializer: UserSerializer,
        meta: { errors: pre_serialized_profile.errors }
      )
    end
  end
end
