# frozen_string_literal: true

require 'mdot/v2/configuration'
require 'mdot/v2/session'

module MDOT::V2
  class Service < Common::Client::Base
    configuration MDOT::V2::Configuration

    STATSD_KEY_PREFIX = 'api.mdot_v2'

    attr_reader(
      :connection,
      :form_data,
      :orders,
      :supplies_resource,
      :user
    )

    def initialize(*args)
      @user = args[:user]
      @form_data = args[:form_data] || {}
    end

    def authenticate
      get_supplies
      handle_error unless connection.success?
      create_session
      set_supplies_resource
      connection.success?
    end

    def create_order
      post_supplies
      handle_error unless connection.success?
      set_orders
      connection.success?
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

    def create_session
      @session = MDOT::V2::Session.create({ uuid: user.uuid, token: })
    end

    def get_supplies
      @connection = get('/supplies', nil, auth_headers, {})
    end

    def order_headers
      { 'VaApiKey' => session&.token }
    end

    def post_supplies
      @connection = post('/supplies', form_data, order_headers, {})
    end

    def token
      connection.response_headers['vaapikey']
    end

    def session
      @session ||= MDOT::V2::Session.find(uuid: user.uuid)
    end

    def set_orders
      @orders = connection.response_body
    end

    def set_supplies_resource
      permitted_params = %w[permanentAddress temporaryAddress vetEmail supplies].freeze
      @supplies_resource = connection.response_body&.slice(*permitted_params)
    end

    def handle_error
      # if 401 and this -> unauthorized message
      # if 500 and connection.response_body['message'] ~= /SQL/ -> try again?
    end
  end
end
