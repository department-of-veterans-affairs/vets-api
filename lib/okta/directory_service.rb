# frozen_string_literal: true

require 'rest-client'

module Okta
  class DirectoryService < Common::Client::Base
    def scopes(category)
      # if the category is health we need to call a specific server instead of relying on querying by name,
      # since there is a 'health/systems' auth server that would affect results

      base_url = Settings.authorization_server_scopes_api.auth_server.url

      scopes_url = "#{base_url}/#{category}"

      puts scopes_url

      headers = { apiKey: Settings.connected_apps_api.connected_apps.api_key }

      puts headers

      response = RestClient::Request.execute(method: :get, url: scopes_url, headers:)

      puts response

      if response.code == 200
        JSON.parse(response.body)
      else
        { 'error' => 'Failed to fetch scopes' }
      end
    end
  end
end
