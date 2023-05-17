# frozen_string_literal: true

require 'sidekiq'

module VAForms
  class FormReloader
    include Sidekiq::Worker

    sidekiq_options retries: 7

    def perform
      Rails.logger.info("#{self.class.name} is being called.")

      all_forms_data.each { |form| VAForms::FormBuilder.perform_async(form) }

      # append new tags for pg_search
      VAForms::UpdateFormTagsService.run
    rescue => e
      Rails.logger.error("#{self.class.name} failed to run!", e)
    end

    def all_forms_data
      query = File.read(Rails.root.join('modules', 'va_forms', 'config', 'graphql_query.txt'))
      body = { query: }
      response = connection.post do |req|
        req.path = 'graphql'
        req.body = body.to_json
        req.options.timeout = 300
      end
      JSON.parse(response.body).dig('data', 'nodeQuery', 'entities')
    end

    def connection
      basic_auth_class = Faraday::Request::BasicAuthentication
      @connection ||= Faraday.new(Settings.va_forms.drupal_url, faraday_options) do |faraday|
        faraday.request :url_encoded
        faraday.use basic_auth_class, Settings.va_forms.drupal_username, Settings.va_forms.drupal_password
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
