# frozen_string_literal: true

require 'mdot/v2/configuration'

module MDOT::V2
  class Service < Common::Client::Base
    configuration MDOT::V2::Configuration

    STATSD_KEY_PREFIX = 'api.mdot_v2'

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def authenticate
      response = get("/supplies", nil, auth_headers, {})
    end

    def create_order; end

    private

    def auth_headers
      {
        'VA_VETERAN_FIRST_NAME' => user.first_name,
        'VA_VETERAN_MIDDLE_NAME' => user.middle_name || ' ',
        'VA_VETERAN_LAST_NAME' => user.last_name,
        'VA_VETERAN_ID' => user.ssn[-4..-1],
        'VA_VETERAN_BIRTH_DATE' => user.birth_date,
        'VA_ICN' => user.icn || ' '
      }
    end
  end
end
