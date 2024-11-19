# frozen_string_literal: true

require 'banners/engine'
require 'banners/builder'
require 'banners/profile/vacms'
module Banners
  class Updater
    # If banners are to be added in the future, include them here by adding
    # another #update_{type_of}_banners method for #perform to call
    def self.perform
      banner_updater = new
      banner_updater.update_vacms_banners
    end

    def update_vacms_banners
      vacms_banner_data.each do |banner_data|
        Builder.perform_async(Profile::Vacms.parsed_banner(banner_data))
      end
    end

    def vacms_banner_data
      banner_graphql_query = Rails.root.join('modules', 'banners', 'config', 'vacms_graphql_query.txt')
      body = { query: File.read(banner_graphql_query) }

      response = connection.post do |req|
        req.path = 'graphql'
        req.body = body.to_json
        req.options.timeout = 300
      end

      begin
        JSON.parse(response.body).dig('data', 'nodeQuery', 'entities')
      rescue JSON::ParserError
        []
      end
    end

    private

    def connection
      @connection ||= Faraday.new(Settings.va_forms.drupal_url, faraday_options) do |faraday|
        faraday.request :url_encoded
        faraday.request :authorization, :basic, Settings.va_forms.drupal_username, Settings.va_forms.drupal_password
        faraday.adapter faraday_adapter
      end
    end

    def faraday_adapter
      Rails.env.production? ? Faraday.default_adapter : :net_http_socks
    end

    def faraday_options
      options = { ssl: { verify: false } }
      options[:proxy] = { uri: URI.parse('socks://localhost:2001') } unless Rails.env.production?
      options
    end
  end
end
