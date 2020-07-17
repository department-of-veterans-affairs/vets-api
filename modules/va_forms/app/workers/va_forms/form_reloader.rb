# frozen_string_literal: true

require 'sidekiq'

module VaForms
  class FormReloader
    include Sidekiq::Worker

    FORM_BASE_URL = 'https://www.va.gov'

    def perform
      query = File.read(Rails.root.join('modules', 'va_forms', 'config', 'graphql_query.txt'))
      body = { query: query }
      response = connection.post('graphql', body.to_json)
      forms_data = JSON.parse(response.body)
      processed_forms = []
      forms_data.dig('data', 'nodeQuery', 'entities').each do |form|
        va_form = build_and_save_form(form)
        processed_forms << va_form
      rescue
        next
      end
      mark_stale_forms(processed_forms)
    end

    def connection
      basic_auth_class = Faraday::Request::BasicAuthentication
      @connection ||= Faraday.new(Settings.va_forms.drupal_url, faraday_options) do |faraday|
        faraday.request :url_encoded
        faraday.use basic_auth_class, Settings.va_forms.drupal_username, Settings.va_forms.drupal_password
        faraday.adapter :net_http_socks unless Rails.env.production?
      end
    end

    def faraday_options
      options = {
        ssl: {
          verify: false
        }
      }
      options[:proxy] = { uri: URI.parse('socks://localhost:2001') } unless Rails.env.production?
      options
    end

    def mark_stale_forms(processed_forms)
      processed_form_names = processed_forms.map { |f| f['form_name'] }
      missing_forms = VaForms::Form.where.not(form_name: processed_form_names)
      missing_forms.find_each do |form|
        form.update(valid_pdf: false)
      end
    end

    def build_and_save_form(form)
      va_form = VaForms::Form.find_or_initialize_by form_name: form['fieldVaFormName']
      current_sha256 = va_form.sha256
      url = form['fieldVaFormUrl']['uri']
      va_form_url = url.starts_with?('http') ? url.gsub('http:', 'https:') : expand_va_url(url)
      va_form.url = Addressable::URI.parse(va_form_url).normalize.to_s
      va_form.title = form['fieldVaFormNumber']
      issued_string = form.dig('fieldVaFormIssueDate', 'value')
      va_form.first_issued_on = parse_date(issued_string) if issued_string.present?
      revision_string = form.dig('fieldVaFormRevisionDate', 'value')
      va_form.last_revision_on = parse_date(revision_string) if revision_string.present?
      va_form.pages = form['fieldVaFormNumPages']
      va_form = update_sha256(va_form)
      va_form.save if current_sha256 != va_form.sha256
      va_form
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
      "#{FORM_BASE_URL}/vaforms/#{url.gsub('./', '')}" if url.starts_with?('./va') || url.starts_with?('./medical')
    end
  end
end
