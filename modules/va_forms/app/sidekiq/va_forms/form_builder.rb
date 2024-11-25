# frozen_string_literal: true

require 'sidekiq'
require 'va_forms/regex_helper'

module VAForms
  class FormBuilder
    include Sidekiq::Job

    class FormFetchError < StandardError; end

    STATSD_KEY_PREFIX = 'api.va_forms.form_builder'

    NON_RETRYABLE_ERROR_CODES = [403, 404].freeze # No need to retry because unlikely to recover

    sidekiq_options retry: 7

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      form_data = msg['args'].first
      form_name = form_data['fieldVaFormNumber']
      row_id = form_data['fieldVaFormRowId']

      # Ensure that the form is marked "valid_pdf: false" if successive form fetches have failed
      if error_class.to_s == FormFetchError.to_s
        form = VAForms::Form.find_by(row_id:)
        url = VAForms::Form.normalized_form_url(form_data.dig('fieldVaFormUrl', 'uri'))
        form_previously_valid = form.valid_pdf
        form.update!(valid_pdf: false, sha256: nil, url:)
        if form_previously_valid
          VAForms::Slack::Messenger.new(
            {
              class: job_class.to_s,
              message: "URL for form #{form_name} no longer returns a valid PDF or web page.",
              form_url: url
            }
          ).notify!
        end
      end

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted", tags: { form_name:, row_id: })

      Rails.logger.warn(
        "#{job_class} retries exhausted",
        { job_id:, error_class:, error_message:, form_name:, row_id:, form_data: }
      )
    rescue => e
      Rails.logger.error(
        "Failure in #{job_class}#sidekiq_retries_exhausted",
        {
          messaged_content: e.message,
          job_id:,
          form_name:,
          row_id:,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )
      raise e
    end

    def perform(form_data)
      build_and_save_form(form_data)
    end

    private

    # Given +form_data+ as returned by the graphql query, returns a matching, updated and saved +VAForms::Form+ instance
    def build_and_save_form(form_data)
      form = find_or_initialize_form(form_data)
      attrs = gather_form_attributes(form_data)
      url = VAForms::Form.normalized_form_url(form_data.dig('fieldVaFormUrl', 'uri'))
      attrs[:url] = url if form.new_record?
      form.update!(attrs) # The job can fail later, so save current progress

      if form.deleted_at.present?
        form.update!(valid_pdf: false, sha256: nil)
      else
        attrs = check_form_validity(form, attrs, url)
        form.update!(attrs)
      end
    end

    # Given a +form+, +attrs+, and +url+, makes a request for the form; if response is successful, assigns attributes
    # and sends Slack notifications; if response is unsuccessful, raises an error
    def check_form_validity(form, attrs, url)
      response = fetch_form(url)
      if response.success? || NON_RETRYABLE_ERROR_CODES.include?(response.status)
        attrs[:valid_pdf] = response.success?
        attrs[:sha256] = response.success? ? Digest::SHA256.hexdigest(response.body) : nil
        attrs[:url] = url

        send_slack_notifications(form, attrs, response.headers['Content-Type'])

        attrs
      else
        raise FormFetchError, "The form could not be fetched from the url provided. Response code: #{response.status}"
      end
    end

    # Given a form +url+, makes a request for the form and returns the response
    def fetch_form(url)
      connection = Faraday.new(url) do |conn|
        conn.use Faraday::FollowRedirects::Middleware
        conn.options.open_timeout = 10
        conn.options.timeout = 30
        conn.adapter Faraday.default_adapter
      end
      connection.get
    end

    # Given a +existing_form+ instance of +VAForms::Form+, +updated_attributes+ for that form, and the +content_type+
    # returned by the form URL, sends appropriate Slack notifications
    def send_slack_notifications(existing_form, updated_attrs, content_type)
      if existing_form.valid_pdf && !updated_attrs[:valid_pdf]
        # If the PDF was valid but is no longer valid, notify
        notify_slack(
          "URL for form #{updated_attrs[:form_name]} no longer returns a valid PDF or web page.",
          form_url: updated_attrs[:url]
        )
      elsif existing_form.url != updated_attrs[:url]
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
    end

    # Finds or initializes a matching +VAForms::Form+ based on the given +form_data+ as returned from the graphql query
    def find_or_initialize_form(form_data)
      VAForms::Form.find_or_initialize_by(row_id: form_data['fieldVaFormRowId'])
    end

    # Returns a hash of attributes for a +VAForms::Form+ record based on the given +form_data+
    # rubocop:disable Metrics/MethodLength
    def gather_form_attributes(form_data)
      attrs = {
        form_name: form_data['fieldVaFormNumber'],
        title: form_data['fieldVaFormName'],
        pages: form_data['fieldVaFormNumPages'],
        language: form_data['fieldVaFormLanguage'].presence || 'en',
        form_type: form_data['fieldVaFormType'],
        form_usage: form_data.dig('fieldVaFormUsage', 'processed'),
        form_details_url:
          form_data['entityPublished'] ? "#{VAForms::Form::FORM_BASE_URL}#{form_data.dig('entityUrl', 'path')}" : '',
        form_tool_intro: form_data['fieldVaFormToolIntro'],
        form_tool_url: form_data['entityPublished'] ? form_data.dig('fieldVaFormToolUrl', 'uri') : '',
        deleted_at: form_data.dig('fieldVaFormDeletedDate', 'value'),
        related_forms: form_data['fieldVaFormRelatedForms'].map { |f| f.dig('entity', 'fieldVaFormNumber') },
        benefit_categories: parse_benefit_categories(form_data),
        va_form_administration: form_data.dig('fieldVaFormAdministration', 'entity', 'entityLabel'),
        **parse_form_revision_dates(form_data)
      }

      if (raw_tags = form_data['fieldVaFormNumber'])
        attrs[:tags] = VAForms::RegexHelper.new.strip_va(raw_tags)
      end

      attrs
    end
    # rubocop:enable Metrics/MethodLength

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

    def notify_slack(message, **)
      VAForms::Slack::Messenger.new({ class: self.class.name, message:, ** }).notify!
    rescue => e
      Rails.logger.error("#{self.class.name} failed to notify Slack, message: #{message}", e)
    end
  end
end
