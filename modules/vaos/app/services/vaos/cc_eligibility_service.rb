# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class CCEligibilityService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'  # what's this for?  should it be api.cc?

    attr_accessor :user

    def self.for_user(user)
      as = VAOS::CCEligibilityService.new
      as.user = user
      as
    end


    def get_eligibility(service_type)

      with_monitoring do
        response = perform(:get, get_eligibility_url(service_type), nil, headers(user))
        {
          ### ???
          data: response.body,
          meta: nil
        }
        # responses: 200, 400 (unknown service type), 404 (unknown patient)
      end
    end


    def get_service_types
      # returns [ { name: name, patientFriendlyName: pfn }, ... ]
      with_monitoring do
        response = perform(:get, get_service_types_url, nil, headers(user))
        response.body[:service_types].map { |service_type| OpenStruct.new(service_type) }
      end
      # responses: 200
    end


    private

    def deserialized_cc_eligibility(json_hash)
      if type == 'va'
        json_hash.dig(:data, :appointment_list).map { |appointments| OpenStruct.new(appointments) }
      else
        json_hash[:booked_appointment_collections].first[:booked_cc_appointments]
                                                  .map { |appointments| OpenStruct.new(appointments) }
      end
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash, appointments_type: type)
      []
    end



    def get_eligibility_url(service_type)
        "/cce/v1/patients/#{user.icn}/eligibility/#{service_type}"
    end

    def get_service_types_url
        "/cce/v1/serviceTypes"
    end



  end
end
