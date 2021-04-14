# frozen_string_literal: true

require 'sidekiq'

module VAForms
  class FormReloader
    include Sidekiq::Worker
    include SentryLogging

    FORM_BASE_URL = 'https://www.va.gov'

    def perform
      Rails.logger.info('VAForms::FormReloader is being called.')
      query = File.read(Rails.root.join('modules', 'va_forms', 'config', 'graphql_query.txt'))
      body = { query: query }
      response = connection.post do |req|
        req.path = 'graphql'
        req.body = body.to_json
        req.options.timeout = 300
      end
      forms_data = JSON.parse(response.body)
      forms_data.dig('data', 'nodeQuery', 'entities').each do |form|
        build_and_save_form(form)
      rescue => e
        log_message_to_sentry(
          "#{form['fieldVaFormNumber']} failed to import into forms database",
          :error, body: e.message
        )
        next
      end
    rescue => e
      Rails.logger.error('VAForms::FormReloader failed to run!', e)
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
      options = {
        ssl: {
          verify: false
        }
      }
      socks = Settings.docker_debugging&.socks_url ? Settings.docker_debugging.socks_url : 'socks://localhost:2001'
      options[:proxy] = { uri: URI.parse(socks) } unless Rails.env.production?
      options
    end

    def build_and_save_form(form)
      va_form = VAForms::Form.find_or_initialize_by row_id: form['fieldVaFormRowId']
      attrs = init_attributes(form)
      url = form['fieldVaFormUrl']['uri']
      va_form_url = url.starts_with?('http') ? url.gsub('http:', 'https:') : expand_va_url(url)
      issued_string = form.dig('fieldVaFormIssueDate', 'value')
      revision_string = form.dig('fieldVaFormRevisionDate', 'value')
      attrs[:url] = Addressable::URI.parse(va_form_url).normalize.to_s
      attrs[:first_issued_on] = parse_date(issued_string) if issued_string.present?
      attrs[:last_revision_on] = parse_date(revision_string) if revision_string.present?
      va_form.assign_attributes(attrs)
      va_form = update_sha256(va_form)
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
      mapped[:form_details_url] = "#{FORM_BASE_URL}#{form.dig('entityUrl', 'path')}" if form['entityPublished']
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
      if content.class == Tempfile
        Digest::SHA256.file(content).hexdigest
      else
        Digest::SHA256.hexdigest(content.string)
      end
    end

    def update_sha256(form)
      if form.url.present? && (content = URI.parse(form.url).open)
        form.sha256 = get_sha256(content)
        form.valid_pdf = true
      else
        form.valid_pdf = false
      end
      form
    rescue
      form.valid_pdf = false
      form
    end

    def expand_va_url(url)
      raise ArgumentError, 'url must start with ./va or ./medical' unless url.starts_with?('./va', './medical')

      "#{FORM_BASE_URL}/vaforms/#{url.gsub('./', '')}" if url.starts_with?('./va') || url.starts_with?('./medical')
    end
  end
end
