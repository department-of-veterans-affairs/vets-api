# frozen_string_literal: true

require 'va_profile/profile/v3/service'

module V0
  module Profile
    class ContactsController < ApplicationController
      service_tag 'profile'
      before_action { authorize :vet360, :access? }

      # GET /v0/profile/contacts
      def index
        response = service.get_health_benefit_bio
        render(
          status: response.status,
          json: response.contacts,
          serializer: CollectionSerializer,
          each_serializer: ContactSerializer
        )
      end

      private

      def service
        VAProfile::Profile::V3::Service.new(current_user)
      end
    end
  end
end
