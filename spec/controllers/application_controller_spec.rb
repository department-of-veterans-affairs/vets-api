# frozen_string_literal: true

require 'rails_helper'
require 'rx/client' # used to stub Rx::Client in tests

RSpec.describe ApplicationController, type: :controller do
  controller do
    attr_reader :payload

    skip_before_action :authenticate, except: %i[test_authentication test_logging]

    JSON_ERROR = {
      'errorCode' => 139, 'developerMessage' => '', 'message' => 'Prescription is not Refillable'
    }.freeze

    def not_authorized
      raise Pundit::NotAuthorizedError
    end

    def unauthorized
      raise Common::Exceptions::Unauthorized
    end

    def routing_error
      raise Common::Exceptions::RoutingError
    end

    def forbidden
      raise Common::Exceptions::Forbidden
    end

    def test_logging
      Rails.logger.info sso_logging_info
    end

    def breakers_outage
      Rx::Configuration.instance.breakers_service.begin_forced_outage!
      client = Rx::Client.new(session: { user_id: 123 })
      client.get_session
    end

    def record_not_found
      raise Common::Exceptions::RecordNotFound, 'some_id'
    end

    def other_error
      raise Common::Exceptions::BackendServiceException, 'RX139'
    end

    def common_error_with_warning_sentry
      raise Common::Exceptions::BackendServiceException, 'VAOS_409A'
    end

    def client_connection_failed
      client = Rx::Client.new(session: { user_id: 123 })
      client.get_session
    end

    def test_authentication
      head :ok
    end

    def append_info_to_payload(payload)
      super
      @payload = payload
    end
  end

  before do
    routes.draw do
      get 'test_logging' => 'anonymous#test_logging'
      get 'not_authorized' => 'anonymous#not_authorized'
      get 'unauthorized' => 'anonymous#unauthorized'
      get 'routing_error' => 'anonymous#routing_error'
      get 'forbidden' => 'anonymous#forbidden'
      get 'breakers_outage' => 'anonymous#breakers_outage'
      get 'common_error_with_warning_sentry' => 'anonymous#common_error_with_warning_sentry'
      get 'record_not_found' => 'anonymous#record_not_found'
      get 'other_error' => 'anonymous#other_error'
      get 'client_connection_failed' => 'anonymous#client_connection_failed'
      get 'client_connection_failed_no_sentry' => 'anonymous#client_connection_failed_no_sentry'
      get 'test_authentication' => 'anonymous#test_authentication'
    end
  end
end
