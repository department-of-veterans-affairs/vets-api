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

    def perform(form_data)
      build_and_save_form(form_data)
    rescue => e
      form_name = form_data['fieldVaFormNumber']
      message = "#{self.class.name} failed to import #{form_name} into forms database"
      Rails.logger.error(message, e)
      log_message_to_sentry(message, :error, body: e.message)
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure", tags: { form_name: })
      raise
    end

    # Given +form_data+ as returned by the graphql query, returns a matching, updated and saved +VAForms::Form+ instance
    def build_and_save_form(form_data)
      form = find_or_create_form(form_data)
      attrs = gather_form_attributes(form_data)

      maybe_pdf, content_type = fetch_form_pdf(attrs[:url])
      attrs[:valid_pdf] = maybe_pdf.present?
      attrs[:sha256] = Digest::SHA256.hexdigest(maybe_pdf) if maybe_pdf.present?

      send_notifications(form, attrs, content_type)

      form.update!(attrs)
      form
    end

    # Given a +existing_form+ instance of +VAForms::Form+, +updated_attributes+ for that form, and the +content_type+
    # returned by the form URL, send appropriate Slack notifications
    def send_notifications(existing_form, updated_attrs, content_type)
      if updated_attrs[:valid_pdf]
        if existing_form.url != updated_attrs[:url]
          # If the URL has changed, we notify regardless of content
          notify_slack(
            "Form #{updated_attrs[:form_name]} has been updated.",
            from_form_url: existing_form.url,
            to_form_url: updated_attrs[:url]
          )
        elsif existing_form.sha256 != updated_attrs[:sha256] && content_type == 'application/pdf'
          # If sha256 has changed, only notify if the URL actually returns a PDF, because if the URL is for a download
          # web page instead, the change in sha256 may not actually reflect a change in the PDF itself
          notify_slack("PDF contents of form #{updated_attrs[:form_name]} have been updated.")
        end
      elsif existing_form.valid_pdf
        # If PDF is not valid, only notify if it was previously valid
        notify_slack(
          "URL for form #{updated_attrs[:form_name]} no longer returns a valid PDF or web page.",
          form_url: updated_attrs[:url]
        )
      end
    end

    # Finds or creates a matching +VAForms::Form+ based on the given +form_data+ as returned from the graphql query
    def find_or_create_form(form_data)
      VAForms::Form.find_or_initialize_by row_id: form_data['fieldVaFormRowId']
    end

    # Returns a hash of attributes for a +VAForms::Form+ record based on the given +form_data+
    # rubocop:disable Metrics/MethodLength
    def gather_form_attributes(form_data)
      form_url = normalize_form_url(form_data.dig('fieldVaFormUrl', 'uri'))

      attrs = {
        form_name: form_data['fieldVaFormNumber'],
        title: form_data['fieldVaFormName'],
        pages: form_data['fieldVaFormNumPages'],
        language: form_data['fieldVaFormLanguage'].presence || 'en',
        form_type: form_data['fieldVaFormType'],
        form_usage: form_data.dig('fieldVaFormUsage', 'processed'),
        form_details_url: form_data['entityPublished'] ? "#{FORM_BASE_URL}#{form_data.dig('entityUrl', 'path')}" : '',
        form_tool_intro: form_data['fieldVaFormToolIntro'],
        form_tool_url: form_data.dig('fieldVaFormToolUrl', 'uri'),
        deleted_at: form_data.dig('fieldVaFormDeletedDate', 'value'),
        related_forms: form_data['fieldVaFormRelatedForms'].map { |f| f.dig('entity', 'fieldVaFormNumber') },
        benefit_categories: parse_benefit_categories(form_data),
        va_form_administration: form_data.dig('fieldVaFormAdministration', 'entity', 'entityLabel'),
        url: form_url,
        **parse_form_revision_dates(form_data)
      }

      if (raw_tags = form_data['fieldVaFormNumber'])
        attrs[:tags] = VAForms::RegexHelper.new.strip_va(raw_tags)
      end

      attrs
    end
    # rubocop:enable Metrics/MethodLength

    # Normalizes a +url+ that may not be a full, valid URL or  may not use https
    def normalize_form_url(url)
      va_form_url = url.starts_with?('http') ? url.gsub('http:', 'https:') : expand_va_url(url)
      Addressable::URI.parse(va_form_url).normalize.to_s
    end

    # Parses a given date string and returns it in MM-YYYY or YYYY-MM-DD format
    def parse_date(date_string)
      Date.strptime(date_string, date_string.split('-').count == 2 ? '%m-%Y' : '%Y-%m-%d')
    end

    # Parses values for +first_issued_on+ and +last_revision_on+ dates from the given +form_data+
    def parse_form_revision_dates(form_data)
      dates = {}

      if (issued_string = form_data.dig('fieldVaFormIssueDate', 'value'))
        dates[:first_issued_on] = parse_date(issued_string)
      end

      if (revision_string = form_data.dig('fieldVaFormRevisionDate', 'value'))
        dates[:last_revision_on] = parse_date(revision_string)
      end

      dates
    end

    # Parses an array of valid category name & description hashes from the given +form_data+
    def parse_benefit_categories(form_data)
      form_data['fieldBenefitCategories'].map do |field|
        {
          name: field.dig('entity', 'fieldHomePageHubLabel'),
          description: field.dig('entity', 'entityLabel')
        }
      end
    end

    # Attempts to download and return a tuple of [request body, content type] from the given +url+. If the +url+ doesn't
    # successfully return a body, this will raise an error if it's still possible to retry the job.
    def fetch_form_pdf(url)
      connection = Faraday.new(url) do |conn|
        conn.use FaradayMiddleware::FollowRedirects
        conn.options.open_timeout = 10
        conn.options.timeout = 30
        conn.adapter Faraday.default_adapter
      end
      response = connection.get
      content_type = response.headers['Content-Type']
      return [response.body, content_type] if response.success?

      unless final_retry? # Unless we're on the final retry, raise this failure to trigger a retry
        message = 'A valid PDF could not be fetched'
        details = { response_code: response.status, content_type:, url:, current_retry: @current_retry }
        Rails.logger.error(message, details)
        raise message
      end

      [nil, '']
    end

    def final_retry?
      @current_retry.to_i == RETRIES
    end

    def expand_va_url(url)
      raise ArgumentError, 'url must start with ./va or ./medical' unless url.starts_with?('./va', './medical')

      "#{FORM_BASE_URL}/vaforms/#{url.gsub('./', '')}" if url.starts_with?('./va') || url.starts_with?('./medical')
    end

    def notify_slack(message, **)
      return unless Settings.va_forms.slack.enabled

      begin
        VAForms::Slack::Messenger.new({ class: self.class.name, message:, ** }).notify!
      rescue => e
        Rails.logger.error("#{self.class.name} failed to notify Slack, message: #{message}", e)
      end
    end
  end
end
