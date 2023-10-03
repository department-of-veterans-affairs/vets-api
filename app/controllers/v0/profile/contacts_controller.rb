# frozen_string_literal: true

module V0
  module Profile
    class ContactsController < ApplicationController
      before_action :check_feature_enabled

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
        routing_error unless Flipper.enabled?('profile_contacts')
      end

      def service
        VAProfile::HealthBenefit::Service.new(current_user)
      end
    end
  end
end
