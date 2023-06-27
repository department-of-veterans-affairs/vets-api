# frozen_string_literal: true

require 'common/client/base'
require 'okta/service'

module Okta
  class DirectoryService < Common::Client::Base
    DEFAULT_OKTA_SCOPES = %w[openid profile email address phone offline_access device_sso].freeze

    attr_accessor :okta_service

    def initialize
      @okta_service = Okta::Service.new
    end

    def scopes(category)
      # if the category is health we need to call a specific server instead of relying on querying by name,
      # since there is a 'health/systems' auth server that would affect results
      category == 'health' ? handle_health_server : handle_nonhealth_server(category)
    end

    def handle_health_server
      server = okta_service.auth_server(Settings.directory.health_server_id)
      scopes = okta_service.get_server_scopes(server.body['id'])
      remove_scope_keys(scopes)
    end

    def handle_nonhealth_server(category)
      servers = okta_service.auth_servers
      server = servers.body.select { |auth_server| auth_server['name'].include?(category.downcase) }
      return server if server.empty?

      scopes = @okta_service.get_server_scopes(server[0]['id'])
      remove_scope_keys(scopes)
    end

    def remove_scope_keys(scopes)
      # Removing unneccesary key/value pairs from the Okta Response.
      # Our response only requires the names and description
      parsed_scopes = scopes.body.each do |item|
        item.select! { |k, _v| %w[name displayName description].include?(k.to_s) }
      end
      # Removing the default scopes assigned to each Okta Authorization Server
      remove_base_okta_scopes(parsed_scopes)
    end

    def remove_base_okta_scopes(scopes)
      scopes.delete_if { |scope| DEFAULT_OKTA_SCOPES.include? scope['name'] }
    end
  end
end
