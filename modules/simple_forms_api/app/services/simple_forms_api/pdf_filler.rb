# frozen_string_literal: true

module SimpleFormsApi
  class PdfFiller
    attr_accessor :data, :form_number

    TEMPLATE_BASE = Rails.root.join('modules', 'simple_forms_api', 'templates')

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
      template = Rails.root.join('modules', 'simple_forms_api', 'app', 'form_mappings', "#{form_number}.json.erb").read
      b = binding
      b.local_variable_set(:data, data)
      result = ERB.new(template).result(b)
      JSON.parse(escape_json_string(result))
    end

    def metadata
      klass = "SimpleFormsApi::#{form_number.titleize.gsub(' ', '')}".constantize.new(data)
      klass.metadata
    end

    def escape_json_string(str)
      # remove characters that will break the json parser
      # \u0000-\u001f: control characters in the ASCII table,
      # characters such as null, tab, line feed, and carriage return
      # \u0080-\u009f: control characters in the Latin-1 Supplement block of Unicode
      # \u2000-\u201f: various punctuation and other non-printable characters in Unicode,
      # including various types of spaces, dashes, and quotation marks.
      str.gsub(/[\u0000-\u001f\u0080-\u009f\u2000-\u201f]/, ' ')
    end
  end
end
