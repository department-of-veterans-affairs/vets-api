# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V2
    class UserSerializer
      include JSONAPI::Serializer

      set_type :user
      attributes :id, :first_name, :middle_name, :last_name, :signin_email, :signin_service

      def initialize(user)
        @user = user
        resource = UserStruct.new(user.uuid, user.first_name, user.middle_name, user.last_name, user.email,
                                  user.identity.sign_in[:service_name].remove('oauth_'))
        super(resource)
      end

      UserStruct = Struct.new(:id, :first_name, :middle_name, :last_name, :signin_email, :signin_service)
    end
  end
end
