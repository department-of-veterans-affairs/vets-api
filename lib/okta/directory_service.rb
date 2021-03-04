# frozen_string_literal: true

require 'common/client/base'

module Okta
  class DirectoryService < Common::Client::Base
    DEFAULT_OKTA_SCOPES = %w[openid profile email address phone offline_access].freeze

    def initialize
      @okta_service = Okta::Service.new
    end

    def scopes(category)
      # if the category is health we need to call a specific server instead of relying on querying by name,
      # since there is a 'health/systems' auth server that would affect results
      category == 'health' ? handle_health_server : handle_nonhealth_server(category)
    end

    def handle_health_server
      server = @okta_service.get_auth_server(Settings.directory.health_server_id)
      scopes = @okta_service.get_server_scopes(server.body['id'])
      remove_okta_base_scopes(scopes)
    end

    def handle_nonhealth_server(category)
      servers = @okta_service.get_auth_servers
      server = servers.body.select { |auth_server| auth_server['name'].include?(category.downcase) }
      p server
      if server.empty?
        return server
      end
      scopes = @okta_service.get_server_scopes(server[0]['id'])
      p scopes
      remove_okta_base_scopes(scopes)
    end

    def remove_okta_base_scopes(scopes)
      # Removing unneccesary key/value pairs from the Okta Response.
      # Our response only requires the names and description
      parsed_scopes = scopes.body.each do |item|
        item.select! { |k, _v| %w[name displayName description].include?(k) }
      end
      # Removing the default scopes assigned to each Okta Authorization Server
      parsed_scopes.delete_if { |scope| DEFAULT_OKTA_SCOPES.include? scope['name'] }
      parsed_scopes
    end
  end
end
