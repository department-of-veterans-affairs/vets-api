# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V2
    class UserSerializer
      include JSONAPI::Serializer

      set_type :user
      attributes :id, :first_name, :middle_name, :last_name, :signin_email, :birth_date, :signin_service,
                 :has_facility_transitioning_to_cerner

      def initialize(user)
        @user = user
        birth_date = user.birth_date.nil? ? nil : Date.parse(user.birth_date).iso8601
        resource = UserStruct.new(user.uuid, user.first_name, user.middle_name, user.last_name, user.email,
                                  birth_date, user.identity.sign_in[:service_name].remove('oauth_'),
                                  transitioning_facility?(user))
        super(resource)
      end

      # this is a temporary fix
      def transitioning_facility?(user)
        Flipper.enabled?(:mobile_cerner_transition, user) &&
          user.va_treatment_facility_ids.include?('556')
      end

      UserStruct = Struct.new(
        :id, :first_name, :middle_name, :last_name, :signin_email, :birth_date, :signin_service,
        :has_facility_transitioning_to_cerner
      )
    end
  end
end
