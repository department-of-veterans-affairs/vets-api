# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class CCEligibilityService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    attr_accessor :user

    def self.for_user(user)
      as = VAOS::CCEligibilityService.new
      as.user = user
      as
    end


    def get_eligibility(service_type)

      with_monitoring do
        response = perform(:get, url(service_type), nil, headers(user))
        {
          data: OpenStruct.new(response.body),
          meta: {}
        }
      end
    end


    private

    def url(service_type)
        "/cce/v1/patients/#{user.icn}/eligibility/#{service_type}"
    end

  end
end
