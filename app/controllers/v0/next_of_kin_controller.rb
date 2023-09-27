# frozen_string_literal: true

module V0
  class NextOfKinController < ApplicationController
    before_action :check_feature_enabled

    # GET /v0/next_of_kin
    def index
      response = service.get_next_of_kin
      render(
        json: response.associated_persons,
        each_serializer: NextOfKinSerializer
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
