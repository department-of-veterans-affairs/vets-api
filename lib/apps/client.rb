# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'
require_relative 'responses/response'
require 'erb'
require 'vets/shared_logging'

module Apps
  # Proxy Service for Apps API.
  class Client < Common::Client::Base
    include Vets::SharedLogging
    include Common::Client::Concerns::Monitoring

    configuration Apps::Configuration

    STATSD_KEY_PREFIX = 'api.apps'

    attr_reader :search_term

    def initialize(search_term = nil)
      @search_term = search_term
    end

    # Get all apps
    #
    def get_all
      with_monitoring do
        raw_response = perform(:get, 'directory', nil)
        Apps::Responses::Response.new(raw_response.status, raw_response.body, 'apps')
      end
    rescue => e
      handle_error(e)
    end

    # Get an individual app
    #
    def get_app
      with_monitoring do
        escaped_code = ERB::Util.url_encode(@search_term)
        raw_response = perform(:get, "directory/#{escaped_code}", nil)
        Apps::Responses::Response.new(raw_response.status, raw_response.body, 'app')
      end
    rescue => e
      handle_error(e)
    end

    # Get the scopes an app with a given service_category could request
    #
    def get_scopes
      with_monitoring do
        raw_response = perform(:get, "directory/scopes/#{@search_term}", nil)
        Apps::Responses::Response.new(raw_response.status, raw_response.body, 'scopes')
      end
    rescue => e
      handle_error(e)
    end

    private

    def handle_error(error)
      case error
      when Common::Client::Errors::ClientError
        save_error_details(error)
        raise_backend_exception('APPS_502', self.class, error)
      else
        raise error
      end
    end

    def save_error_details(error)
      Sentry.set_tags(external_service: self.class.to_s.underscore)

      Sentry.set_extras(
        url: config.base_path,
        message: error.message,
        body: error.body
      )
    end
  end
end
