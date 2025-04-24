# frozen_string_literal: true

require 'mdot/v2/configuration'
require 'mdot/v2/session'

module MDOT::V2
  class Service < Common::Client::Base
    configuration MDOT::V2::Configuration

    STATSD_KEY_PREFIX = 'api.mdot_v2'

    TOKEN_HEADER = 'VaApiKey'

    attr_reader(
      :form_data,
      :error,
      :orders,
      :response,
      :session,
      :supplies_resource,
      :user
    )

    def initialize(user:, form_data: {})
      @user = user
      @form_data = form_data
      get_session
    end

    def authenticate
      get_supplies

      if response.success?
        create_session
        set_supplies_resource
      else
        set_error
      end

      response.success?
    end

    def create_order
      post_supplies

      if response.success?
        set_orders
      else
        set_error
      end

      response.success?
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

    def get_session
      @session = MDOT::V2::Session.find(user.uuid)
    end

    def get_supplies
      @response = get('/supplies', nil, auth_headers, {})
    end

    def order_headers
      { TOKEN_HEADER => session&.token }
    end

    def post_supplies
      @response = post('/supplies', form_data, order_headers, {})
    end

    def set_error
      permitted_params = %w[timestamp message details result]
      @error = response.body&.slice(*permitted_params)
    end

    def set_orders
      @orders = response.response_body
    end

    def set_supplies_resource
      permitted_params = %w[permanentAddress temporaryAddress vetEmail supplies].freeze
      @supplies_resource = response.response_body&.slice(*permitted_params)
    end

    def token
      response.response_headers[TOKEN_HEADER]
    end
  end
end
