# frozen_string_literal: true

require 'sidekiq'
require 'va_forms/regex_helper'

module VAForms
  class FormBuilder
    include Sidekiq::Worker
    include SentryLogging

    # @current_retry set by Sidekiq middleware
    attr_accessor :current_retry

    RETRIES = 7 # Try 7 times over ~46 minutes
    FORM_BASE_URL = 'https://www.va.gov'
    STATSD_KEY_PREFIX = 'api.va_forms.form_builder'

    sidekiq_options(retries: RETRIES)

    def perform(form)
      build_and_save_form(form)
    rescue => e
      message = "#{self.class.name} failed to import #{form['fieldVaFormNumber']} into forms database"
      Rails.logger.error(message, e)
      log_message_to_sentry(message, :error, body: e.message)
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure", tags: { form_name: form['fieldVaFormNumber'] })
      raise
    end

    def build_and_save_form(form)
      va_form = VAForms::Form.find_or_initialize_by row_id: form['fieldVaFormRowId']
      attrs = init_attributes(form)
      new_url = form['fieldVaFormUrl']['uri']
      va_form_url = new_url.starts_with?('http') ? new_url.gsub('http:', 'https:') : expand_va_url(new_url)
      normalized_url = Addressable::URI.parse(va_form_url).normalize.to_s
      issued_string = form.dig('fieldVaFormIssueDate', 'value')
      revision_string = form.dig('fieldVaFormRevisionDate', 'value')
      attrs[:url] = normalized_url
      attrs[:first_issued_on] = parse_date(issued_string) if issued_string.present?
      attrs[:last_revision_on] = parse_date(revision_string) if revision_string.present?
      va_form.assign_attributes(attrs)
      va_form = validate_form(va_form)
      number_tag = VAForms::RegexHelper.new.strip_va(form['fieldVaFormNumber'])
      va_form.tags = va_form.tags.presence || number_tag
      va_form.save
      va_form
    end

    def init_attributes(form)
      mapped = {
        form_name: form['fieldVaFormNumber'],
        title: form['fieldVaFormName'],
        pages: form['fieldVaFormNumPages'],
        language: form['fieldVaFormLanguage'].presence || 'en',
        form_type: form['fieldVaFormType'],
        form_usage: form.dig('fieldVaFormUsage', 'processed'),
        form_tool_intro: form['fieldVaFormToolIntro'],
        form_tool_url: form.dig('fieldVaFormToolUrl', 'uri'),
        deleted_at: form.dig('fieldVaFormDeletedDate', 'value'),
        related_forms: form['fieldVaFormRelatedForms'].map { |f| f.dig('entity', 'fieldVaFormNumber') },
        benefit_categories: map_benefit_categories(form['fieldBenefitCategories']),
        va_form_administration: form.dig('fieldVaFormAdministration', 'entity', 'entityLabel')
      }
      mapped[:form_details_url] = form['entityPublished'] ? "#{FORM_BASE_URL}#{form.dig('entityUrl', 'path')}" : ''
      mapped
    end

    def map_benefit_categories(categories)
      categories.map do |field|
        {
          name: field.dig('entity', 'fieldHomePageHubLabel'),
          description: field.dig('entity', 'entityLabel')
        }
      end
    end

    def parse_date(date_string)
      matcher = date_string.split('-').count == 2 ? '%m-%Y' : '%Y-%m-%d'
      Date.strptime(date_string, matcher)
    end

    def validate_form(form)
      if form.url.present?
        form = check_pdf_validity(form)
      else
        form.valid_pdf = false
      end
      form
    end

    def check_pdf_validity(form)
      response = fetch_form_pdf(form.url)
      content_type = response.headers['Content-Type']

      if response.success?
        form.sha256 = get_sha256(form, response.body)
        form.valid_pdf = true
      elsif final_retry?
        notify_slack("Form #{form.form_name} no longer returns a valid PDF.", form.url) if form.valid_pdf
        form.valid_pdf = false
      else
        message = 'A valid PDF could not be fetched'
        details = { response_code: response.status, content_type:, url: form.url, current_retry: @current_retry }
        Rails.logger.error(message, details)
        raise message # Raise and let the job retry
      end

      form
    end

    def fetch_form_pdf(url)
      connection = Faraday.new(url) do |conn|
        conn.use FaradayMiddleware::FollowRedirects
        conn.options.open_timeout = 10
        conn.options.timeout = 30
        conn.adapter Faraday.default_adapter
      end
      connection.get
    end

    def get_sha256(form, pdf)
      sha256 = Digest::SHA256.hexdigest(pdf)
      notify_slack("Form #{form.form_name} has been updated.", form.url) if form.sha256 != sha256
      sha256
    end

    def final_retry?
      @current_retry.to_i == RETRIES
    end

    def expand_va_url(url)
      raise ArgumentError, 'url must start with ./va or ./medical' unless url.starts_with?('./va', './medical')

      "#{FORM_BASE_URL}/vaforms/#{url.gsub('./', '')}" if url.starts_with?('./va') || url.starts_with?('./medical')
    end

    def notify_slack(message, form_url)
      return unless Settings.va_forms.slack.enabled

      begin
        VAForms::Slack::Messenger.new({ class: self.class.name, message:, form_url: }).notify!
      rescue => e
        Rails.logger.error("#{self.class.name} failed to notify Slack, message: #{message}", e)
      end
    end
  end
end
