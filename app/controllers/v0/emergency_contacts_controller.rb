# frozen_string_literal: true

module V0
  class EmergencyContacts < ApplicationController
    # GET /v0/emergency_contacts
    def index
      render(json: service.get_emergency_contacts)
    end

    # POST /v0/emergency_contacts
    def create
      emergency_contact = VAProfile::Models::AssociatedPerson.new(emergency_contact_params)
      response = service.post_emergency_contacts(emergency_contact)
      render(json: response)
    end

    private

    def service
      VAProfile::HealhtBenefit::Service.new(current_user)
    end

    def emergency_contact_params
      params.require(:emergency_contact).permit(
        :name,
        :address,
        :relationship,
        :phone,
        :work_phone
      )
    end
  end
end
