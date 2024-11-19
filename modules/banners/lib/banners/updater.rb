# frozen_string_literal: true

require 'banners/builder'
require 'banners/profile/vamc'

module Banners
  class Updater
    # If banners are to be added in the future, include them here by adding
    # another #update_{type_of}_banners method for #perform to call
    def self.perform
      banner_updater = new
      banner_updater.update_vamc_banners
    end

    def update_vamc_banners
      vamcs_banner_data.each do |banner_data|
        Builder.perform(Profile::Vamc.parsed_banner(banner_data))
      end

      # Delete any banners that are no longer in the list of banners for VAMCS
      entity_ids_to_keep = vamcs_banner_data.map { |banner_data| banner_data['entityId'] }
      Banner.where.not(entity_id: entity_ids_to_keep).destroy_all
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

    def vamcs_banner_data
      banner_graphql_query = Rails.root.join('modules', 'banners', 'config', 'vamcs_graphql_query.txt')
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
  end
end
