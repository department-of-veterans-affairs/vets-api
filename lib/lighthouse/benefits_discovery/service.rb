# frozen_string_literal: true

module BenefitsDiscovery
  class Service < Common::Client::Base
    configuration BenefitsDiscovery::Configuration

    def get_eligible_benefits
      response = perform(:get, 'benefits-discovery-service/v0/recommendations', example_params, headers)
    end

    def example_params
      {
        "dateOfBirth": "1995-01-01",
        "dischargeStatus": "HONORABLE_DISCHARGE",
        "branchOfService": "NAVY",
        "disabilityRating": 60,
        "serviceDates": [
          {
            "startDate": "2002-03-15",
            "endDate": "2006-08-31"
          }
        ],
        "purpleHeartRecipientDates": [
          "2010-02-01",
          "2012-05-13"
        ]
      }.to_json
    end

    def headers
      {
        'x-api-key' => 'boo',
        'x-app-ida' => 'app_id'
      }
    end
  end
end
