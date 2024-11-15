# frozen_string_literal: true

require 'sidekiq'

module Banners
  class PullAndUpdateDb
    include Sidekiq::Job

    sidekiq_options retry: 7

    STATSD_KEY_PREFIX = 'api.banners.pull_and_update_db'

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      message = "#{job_class} retries exhausted"
      Rails.logger.error(message, { job_id:, error_class:, error_message: })
      # VAForms::Slack::Messenger.new(
      #   {
      #     class: job_class.to_s,
      #     exception: error_class,
      #     exception_message: error_message,
      #     detail: message
      #   }
      # ).notify!
    rescue => e
      message = "Failure in #{job_class}#sidekiq_retries_exhausted"
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
      # VAForms::Slack::Messenger.new(
      #   {
      #     class: job_class.to_s,
      #     exception: e.class.to_s,
      #     exception_message: e.message,
      #     detail: message
      #   }
      # ).notify!

      raise e
    end

    def perform
      return unless enabled?

      # all_forms_data.each { |form| VAForms::FormBuilder.perform_async(form) }

      # # append new tags for pg_search
      # VAForms::UpdateFormTagsService.run
    end

    def all_sites_banner_data
      query = File.read(Rails.root.join('modules', 'banners', 'config', 'graphql_query.txt'))
      body = { query: }
      response = connection.post do |req|
        req.path = 'graphql'
        req.body = body.to_json
        req.options.timeout = 300
      end
      JSON.parse(response.body).dig('data', 'nodeQuery', 'entities')
    end

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

    private

    def enabled?
      true
      # Settings.va_forms.form_reloader.enabled
    end
  end
end
