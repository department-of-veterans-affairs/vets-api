# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V2
    class UserSerializer
      include JSONAPI::Serializer

      set_type :user
      attributes :id, :first_name, :middle_name, :last_name, :signin_email, :birth_date, :signin_service,
                 :has_facility_transitioning_to_cerner, :edipi

      def initialize(user)
        @user = user
        birth_date = user.birth_date.nil? ? nil : Date.parse(user.birth_date).iso8601
        resource = UserStruct.new(user.uuid, user.first_name, user.middle_name, user.last_name, user.email,
                                  birth_date, user.identity.sign_in[:service_name].remove('oauth_'),
                                  transitioning_facility?(user), user.edipi)
        super(resource)
      end

      # when a facility is transitioning to cerner, we use the has_facility_transitioning_to_cerner
      # attribute to inform the user that data and functionality relating to one of their facilities
      # may not be working. Facility 979 is used to support testing lower environments.
      def transitioning_facility?(user)
        ids = Settings.vsp_environment == 'production' ? [] : ['979']
        Flipper.enabled?(:mobile_cerner_transition, user) && user.vha_facility_ids.intersect?(ids)
      end

      UserStruct = Struct.new(
        :id, :first_name, :middle_name, :last_name, :signin_email, :birth_date, :signin_service,
        :has_facility_transitioning_to_cerner, :edipi
      )
    end
  end
end
