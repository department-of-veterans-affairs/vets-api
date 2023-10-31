# frozen_string_literal: true

require 'va_profile/health_benefit/service'

module V0
  module Profile
    class ContactsController < ApplicationController
      service_tag 'profile'
      before_action :check_feature_enabled
      before_action { authorize :vet360, :access? }

      # GET /v0/profile/contacts
      def index
        response = service.get_associated_persons
        render(
          json: response.associated_persons,
          each_serializer: ContactSerializer
        )
      end

      private

      def check_feature_enabled
        routing_error unless Flipper.enabled?('profile_contacts', current_user)
      end

      def service
        VAProfile::HealthBenefit::Service.new(current_user)
      end
    end
  end
end
