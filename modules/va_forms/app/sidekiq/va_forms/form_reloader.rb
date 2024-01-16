# frozen_string_literal: true

require 'sidekiq'

module VAForms
  class FormReloader
    include Sidekiq::Job

    sidekiq_options retry: 7

    STATSD_KEY_PREFIX = 'api.va_forms.form_reloader'

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      message = 'VAForms::FormReloader retries exhausted'
      Rails.logger.error(
        message,
        { job_id:, error_class:, error_message: }
      )
      VAForms::Slack::Messenger.new(
        {
          class: 'VAForms::FormReloader',
          exception: error_class,
          exception_message: error_message,
          detail: message
        }
      ).notify!
    rescue => e
      message = 'Failure in VAForms::FormReloader#sidekiq_retries_exhausted'
      Rails.logger.error(
        message,
        {
          messaged_content: e.message,
          job_id:,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )
      VAForms::Slack::Messenger.new(
        {
          class: 'VAForms::FormReloader',
          exception: error_class,
          exception_message: error_message,
          detail: message
        }
      ).notify!

      raise e
    end

    def perform
      all_forms_data.each { |form| VAForms::FormBuilder.perform_async(form) }

      # append new tags for pg_search
      VAForms::UpdateFormTagsService.run
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
