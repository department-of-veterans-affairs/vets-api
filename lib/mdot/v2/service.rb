# frozen_string_literal: true

require 'mdot/v2/configuration'
require 'mdot/v2/session'

module MDOT::V2
  class Service < Common::Client::Base
    configuration MDOT::V2::Configuration

    STATSD_KEY_PREFIX = 'api.mdot_v2'

    attr_reader :user, :supplies_resource, :orders, :connection

    def initialize(user)
      @user = user
    end

    def authenticate
      @connection = get('/supplies', nil, auth_headers, {})
      handle_error unless connection.success?

      token = connection.response_headers['vaapikey']
      @session = MDOT::V2::Session.create({ uuid: user.uuid, token: })
      permitted_params = %w[permanentAddress temporaryAddress vetEmail supplies].freeze
      @supplies_resource = connection.response_body&.slice(*permitted_params)
      self
    end

    def create_order(form_data)
      @connection = post('/supplies', form_data, order_headers, {})
      handle_error unless connection.success?

      @orders = connection.response_body
    end

    private

    def auth_headers
      {
        'VA_VETERAN_FIRST_NAME' => user.first_name,
        'VA_VETERAN_MIDDLE_NAME' => user.middle_name || ' ',
        'VA_VETERAN_LAST_NAME' => user.last_name,
        'VA_VETERAN_ID' => user.ssn[-4..],
        'VA_VETERAN_BIRTH_DATE' => user.birth_date,
        'VA_ICN' => user.icn || ' '
      }
    end

    def order_headers
      {
        'VaApiKey' => session&.token
      }
    end

    def session
      @session ||= MDOT::V2::Session.find(uuid: user.uuid)
    end

    def handle_error
      # if 401 and this -> unauthorized message
      # if 500 and connection.response_body['message'] ~= /SQL/ -> try again?
    end
  end
end
