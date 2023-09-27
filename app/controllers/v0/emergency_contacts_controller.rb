# frozen_string_literal: true

require 'va_profile/health_benefit/service'

module V0
  class EmergencyContactsController < ApplicationController
    before_action :check_feature_enabled

    skip_before_action :authenticate, if:
      -> { Settings.vet360.health_benefit.mock && Settings.vsp_environment != 'production' }

    # GET /v0/emergency_contacts
    def index
      response = service.get_emergency_contacts
      render(
        json: response.associated_persons,
        each_serializer: EmergencyContactSerializer
      )
    end

    private

    def check_feature_enabled
      routing_error unless Flipper.enabled?('nok_ec_read_only')
    end

    def service
      VAProfile::HealthBenefit::Service.new(current_user)
    end
  end
end
