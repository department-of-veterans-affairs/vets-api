# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_discovery/configuration'

module BenefitsDiscovery
  class Service < Common::Client::Base
    configuration BenefitsDiscovery::Configuration

    def get_eligible_benefits(params = {})
      response = perform(:post, 'benefits-discovery-service/v0/recommendations', permitted_params(params), headers)
      response.body
    end

    private

    def permitted_params(params)
      {
        dateOfBirth: params[:date_of_birth],
        dischargeStatus: params[:discharge_status],
        branchOfService: params[:branch_of_service],
        disabilityRating: params[:disability_rating],
        serviceDates: [
          {
            startDate: params[:service_start_date],
            endDate: params[:service_end_date]
          }.compact.presence
        ].compact,
        purpleHeartRecipientDates: Array.wrap(params[:purple_heart_recipient_dates])
      }.compact_blank.to_json
    end

    def headers
      {
        'x-api-key' => Settings.lighthouse.benefits_discover.x_api_key,
        'x-app-id' => Settings.lighthouse.benefits_discover.x_app_id
      }
    end
  end
end
