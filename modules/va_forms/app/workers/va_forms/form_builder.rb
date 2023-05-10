# frozen_string_literal: true

require 'sidekiq'
require 'va_forms/regex_helper'

module VAForms
  class FormBuilder
    include Sidekiq::Worker
    include SentryLogging
    FORM_BASE_URL = 'https://www.va.gov'

    sidekiq_options(retries: 6) # Try 6 times over ~20 minutes

    def perform(form)
      build_and_save_form(form)
    rescue => e
      message = "#{self.class.name} failed to import #{form['fieldVaFormNumber']} into forms database"
      Rails.logger.error(message, e)
      log_message_to_sentry(message, :error, body: e.message)
      raise
    end

    def build_and_save_form(form)
      va_form = VAForms::Form.find_or_initialize_by row_id: form['fieldVaFormRowId']
      attrs = init_attributes(form)
      new_url = form['fieldVaFormUrl']['uri']
      stored_url = VAForms::Form.where(row_id: form['fieldVaFormRowId']).select('url').first&.url
      va_form_url = new_url.starts_with?('http') ? new_url.gsub('http:', 'https:') : expand_va_url(new_url)
      normalized_url = Addressable::URI.parse(va_form_url).normalize.to_s
      if stored_url != normalized_url && stored_url.present?
        notify_slack(normalized_url, stored_url, form['fieldVaFormNumber'])
      end
      issued_string = form.dig('fieldVaFormIssueDate', 'value')
      revision_string = form.dig('fieldVaFormRevisionDate', 'value')
      attrs[:url] = normalized_url
      attrs[:first_issued_on] = parse_date(issued_string) if issued_string.present?
      attrs[:last_revision_on] = parse_date(revision_string) if revision_string.present?
      va_form.assign_attributes(attrs)
      va_form = update_sha256(va_form)
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

    def get_sha256(content)
      if content.instance_of?(Tempfile)
        Digest::SHA256.file(content).hexdigest
      else
        Digest::SHA256.hexdigest(content.string)
      end
    end

    def update_sha256(form)
      time_initial = Time.zone.now
      if form.url.present? && (content = URI.parse(form.url).open)
        form.sha256 = get_sha256(content)
        form.valid_pdf = true
      else
        form.valid_pdf = false
      end
      Rails.logger.info("Time to open #{form.url}: #{Time.zone.now - time_initial}")
      form
    rescue => e
      message = "#{self.class.name} failed to get SHA-256 hash from form"
      form_data = { form_name: form.form_name, form_url: form.url }.to_s

      Rails.logger.error("#{message}: #{form_data}", e)
      VAForms::Slack::Messenger.new({ class: self.class.name, message:, exception: e, form_data: }).notify!

      form.valid_pdf = false
      form
    end

    def expand_va_url(url)
      raise ArgumentError, 'url must start with ./va or ./medical' unless url.starts_with?('./va', './medical')

      "#{FORM_BASE_URL}/vaforms/#{url.gsub('./', '')}" if url.starts_with?('./va') || url.starts_with?('./medical')
    end

    def notify_slack(old_form_url, new_form_url, form_name)
      return unless Settings.va_forms.slack.enabled

      begin
        slack_details = {
          class: self.class.name,
          alert: "#{form_name} has changed from #{old_form_url} to #{new_form_url}"
        }
        VAForms::Slack::Messenger.new(slack_details).notify!
      rescue => e
        Rails.logger.error("#{self.class.name} failed to notify Slack for form update", e)
      end
    end
  end
end
