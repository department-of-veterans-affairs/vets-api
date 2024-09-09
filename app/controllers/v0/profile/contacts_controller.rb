# frozen_string_literal: true

require 'va_profile/profile/v3/service'

module V0
  module Profile
    class ContactsController < ApplicationController
      service_tag 'profile'
      before_action { authorize :vet360, :access? }
      before_action :check_feature_enabled, only: %i[create update destroy]

      # GET /v0/profile/contacts
      def index
        response = read_service.get_health_benefit_bio
        render json: ContactSerializer.new(response.contacts), status: response.status
      end

      # POST /v0/profile/contacts
      def create
        # use write_service to create a record
      end

      # PUT/PATCH /v0/profile/contacts
      def update
        # use write_service to update a record
      end

      # DELETE /v0/profile/contacts
      def destroy
        # use write_service to set the effectiveEndDate to delete a record
      end

      private

      def read_service
        VAProfile::Profile::V3::Service.new(current_user)
      end

      def write_service
        # VAProfile::HealthBenefit::Service.new(current_user)
      end

      def feature_enabled?
        Flipper.enabled?(:profile_contacts_create_update_delete_enabled, current_user)
      end

      def check_feature_enabled
        routing_error unless feature_enabled?
      end
    end
  end
end
