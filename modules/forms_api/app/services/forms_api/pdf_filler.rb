# frozen_string_literal: true

require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

module FormsApi
  class PdfFiller
    include CentralMail::Utilities

    TEMPLATE_BASE = Rails.root.join('modules', 'forms_api', 'templates')

    attr_accessor :data, :form_number

    def initialize(form_number:, data:)
      @data = data.with_indifferent_access
      @form_number = form_number
    end

    def generate
      template_form_path = "#{TEMPLATE_BASE}/#{form_number}.pdf"
      generated_form_path = "tmp/#{form_number}-tmp.pdf"
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      pdftk.fill_form(template_form_path, generated_form_path, mapped_data)
      PdfStamper.stamp_pdf(generated_form_path, data)
      generated_form_path
    end

    def mapped_data
      template = Rails.root.join('modules', 'forms_api', 'app', 'form_mappings', "#{form_number}.json.erb").read
      b = binding
      b.local_variable_set(:data, data)
      result = ERB.new(template).result(b)
      JSON.parse(result)
    end

    def metadata
      klass = "FormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
      klass.metadata("tmp/#{form_number}-tmp.pdf")
    end
  end
end
