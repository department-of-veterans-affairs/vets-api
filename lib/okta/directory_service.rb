# frozen_string_literal: true

require 'common/client/base'

module Okta
  class DirectoryService < Common::Client::Base
    # matches any ISO date.
    # rubocop:disable Metrics/LineLength
    ISO_PATTERN = /(\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\d\.\d+)|(\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\d)|(\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d)/.freeze
    # rubocop:enable Metrics/LineLength

    def get_apps
      okta_service = Okta::Service.new
      redis = Redis.new
      base_url = Settings.oidc.base_api_url + '/api/v1/apps?limit=200&filter=status+eq+"ACTIVE"'
      # Iterate through the returned applications, and test for pattern matching,
      # adding to our filtered apps array if pattern doesn't match
      unfiltered_apps = recursively_get_apps(okta_service, base_url) #TODO
      filtered_apps = unfiltered_apps.reject { |app| app['label'] =~ ISO_PATTERN } #TODO
      # Create a map of authorization servers,
      # with each server containing a list of all clients and scopes of that server
      auth_server_map = make_server_map(okta_service)
      filtered_apps = parse_scope_permissions(filtered_apps, auth_server_map)
      apps = normalize_schema(filtered_apps)
      # Set cache
      redis.set('okta_directory_apps', apps.to_json)
      apps
    end

    def recursively_get_apps(okta_service, url = '', unfiltered_apps = [])
      apps_response = okta_service.get_apps(url)
      unfiltered_apps.concat(apps_response.body)
      # Check headers for ['link'] where 'rel' == next
      # If the next link exists, call okta_service.get_apps(next_link) and filter based on iso_pattern
      if contains_next(apps_response.headers)
        next_link = substring_next_link(apps_response.headers)
        recursively_get_apps(okta_service, next_link, unfiltered_apps)
      end

      unfiltered_apps
    end

    def contains_next(headers)
      headers['link']&.split(',')&.last&.include?('next')
    end

    def substring_next_link(headers)
      headers['link']&.split(',')&.last&.split('<')&.last&.split('>')&.first
    end

    def make_server_map(okta_service)
      authorization_servers = okta_service.get_auth_servers
      resp_body = authorization_servers.body
      server_client_map = {}
      resp_body.each do |server|
        server_clients = okta_service.get_clients(server['id'])
        server_scopes = okta_service.get_server_scopes(server['id'])
        server_client_map[server['id']] = {
          :clients => server_clients.body,
          :scopes => server_scopes.body
        }
      end
      server_client_map
    end

    def normalize_schema(apps_list)
      normalized_apps = []
      apps_list.each do |app|
        normalized_apps << OktaApplication.new(app)
      end
      normalized_apps
    end

    def parse_scope_permissions(filtered_apps, auth_server_map)
      # For each app in our filtered_apps, if its id is present in a authorization_server's clients array,
      # add each scope description to our the applications permissions array.
      filtered_apps.each do |app|
        auth_server_map.each do |auth_server|
          # if our current app.id is present in the auth server, attach it's scopes to app.permissions
          if auth_server[0]['clients']&.any? { |h| h['client_id'] == app['id'] }
            app['permissions'].concat(auth_server[0][:scopes].collect { |scope| scope[:description] })
          end
        end
        app['permissions'] = app['permissions']&.uniq # remove duplicate scopes that may be shared across auth servers
      end
      filtered_apps
    end
  end
end
