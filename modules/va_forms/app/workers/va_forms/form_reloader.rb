# frozen_string_literal: true

require 'sidekiq'

module VaForms
  class FormReloader
    include Sidekiq::Worker

    BASE_URL = 'https://www.va.gov'

    def perform
      load_page(current_page: 0)
    end

    def load_page(current_page: 0)
      current_page += 1
      page = Faraday.new(url: BASE_URL).post(
        '/vaforms/search_action.asp',
        id: 'form2',
        name: 'form2',
        'CurrentPage' => current_page,
        'Next10' => 'Next25 >'
      ).body
      doc = Nokogiri::HTML(page)
      next_button = doc.css('input[name=Next10]')
      last_page = next_button.first.attributes['disabled'].present?
      parse_page(doc)
      load_page(current_page: current_page) unless last_page
    end

    def parse_page(doc)
      doc.xpath('//table/tr').each do |row|
        parse_table_row(row)
      end
    end

    def parse_table_row(row)
      if row.css('a').try(:first) && (url = row.css('a').first['href'])
        return if url.starts_with?('#')

        begin
          parse_form_row(row, url)
        rescue
          Rails.logger.warn "VA Forms could not open #{url}"
        end
      end
    end

    def parse_form_row(line, url)
      title = line.css('font').text
      form_name = line.css('a').first.text
      form = VaForms::Form.find_or_initialize_by form_name: form_name
      current_sha256 = form.sha256
      form.title = title
      issued_string = line.css('td:nth-child(3)').text
      form.first_issued_on = Date.strptime(issued_string, '%m/%d/%y') if issued_string.present?
      form.last_revision_on = line.css('td:nth-child(4)').text
      form.pages = line.css('td:nth-child(5)').text
      form.url = url.starts_with?('http') ? url : get_full_url(url)
      form.sha256 = get_sha256(form.url)
      form.save if current_sha256 != form.sha256
    end

    def get_sha256(url)
      if url.present?
        content = URI.parse(CGI.escape(url).gsub('%2F', '/').gsub('%3A', ':')).open
        if content.class == Tempfile
          Digest::SHA256.file(content).hexdigest
        else
          Digest::SHA256.hexdigest(content.string)
        end
      end
    end

    def get_full_url(url)
      "https://www.va.gov/vaforms/#{url.gsub('./', '')}" if url.include?('/va') || url.include?('/medical')
    end
  end
end
