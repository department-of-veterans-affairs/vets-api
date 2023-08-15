# frozen_string_literal: true

module Mobile
  module V0
    class AuthorizedServicesSerializer
      include JSONAPI::Serializer

      set_type :authorized_services
      attributes :authorized_services

      def initialize(user_id, authorized_services)
        resource = AuthorizedServicesStruct.new(id: user_id,
                                                authorized_services:)
        super(resource)
      end
    end

    AuthorizedServicesStruct = Struct.new(:id, :authorized_services)
  end
end
