# frozen_string_literal: true

require 'common/client/base'

module Okta
  class DirectoryService < Common::Client::Base
    DEFAULT_OKTA_SCOPES = %w[openid profile email address phone offline_access].freeze

    def scopes(category)
      okta_service = Okta::Service.new
      servers = okta_service.get_auth_servers
      server = servers.body.select { |auth_server| auth_server['name'].include?(category.downcase) }
      if server.empty?
        server
      else
        scopes = okta_service.get_server_scopes(server[0]['id'])
        parsed_scopes = scopes.body.each do |item|
          item.select! { |k, _v| %w[name displayName description].include?(k) }
        end
        parsed_scopes.delete_if { |scope| DEFAULT_OKTA_SCOPES.include? scope['name'] }
        parsed_scopes
      end
    end
  end
end
