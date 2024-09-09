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
        render json: ContactSerializer.new(response.contacts), status: response.status
      end

      # POST /v0/profile/contacts
      def create
        raise routing_error unless feature_enabled?
      end

      # PUT/PATCH /v0/profile/contacts
      def update
        raise routing_error unless feature_enabled?
      end

      # DELETE /v0/profile/contacts
      def destroy
        raise routing_error unless feature_enabled?
      end

      private

      def service
        VAProfile::Profile::V3::Service.new(current_user)
      end

      def feature_enabled?
        Flipper.enable?(:profile_contacts_create_update_delete_enabled, current_user)
      end
    end
  end
end
