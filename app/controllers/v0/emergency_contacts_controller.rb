# frozen_string_literal: true

require 'va_profile/health_benefit/service'

module V0
  class EmergencyContactsController < ApplicationController
    skip_before_action :authenticate, if: -> { Settings.vet360.health_benefit.mock && Settings.vsp_environment != 'production' }

    # GET /v0/emergency_contacts
    def index
      response = service.get_emergency_contacts
      render(
        json: response.associated_persons,
        each_serializer: EmergencyContactSerializer
      )
    end

    # POST /v0/emergency_contacts
    def create
      emergency_contact = VAProfile::Models::AssociatedPerson.new(emergency_contact_params)
      raise Common::Exceptions::ValidationErrors, emergency_contact unless emergency_contact.valid?

      response = service.post_emergency_contacts(emergency_contact)
      render(json: response)
    end

    private

    def service
      VAProfile::HealthBenefit::Service.new(current_user)
    end

    def emergency_contact_params
      params.require(:emergency_contact).permit(
        :contact_type,
        :given_name,
        :family_name,
        :primary_phone
      )
    end
  end
end
