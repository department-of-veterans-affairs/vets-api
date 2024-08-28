# frozen_string_literal: true

require 'common/file_helpers'

module SimpleFormsApi
  class PdfFiller
    attr_accessor :form, :form_number, :name

    TEMPLATE_BASE = Rails.root.join('modules', 'simple_forms_api', 'templates')

    def initialize(form_number:, form:, name: nil)
      raise 'form_number is required' if form_number.blank?
      raise 'form needs a data attribute' unless form&.data

      @form = form
      @form_number = form_number
      @name = name || form_number
    end

    def generate(current_loa = nil)
      template_form_path = "#{TEMPLATE_BASE}/#{form_number}.pdf"
      generated_form_path = Rails.root.join("tmp/#{name}-tmp.pdf").to_s
      stamped_template_path = Rails.root.join("tmp/#{name}-stamped.pdf").to_s
      pdftk = PdfForms.new(Settings.binaries.pdftk)

      # Tempfile workaround inspired by this:
      #   https://github.com/actions/runner-images/issues/4443#issuecomment-965391736
      tempfile = Tempfile.new(['', '.pdf'], Rails.root.join('tmp')).tap do |tmpfile|
        IO.copy_stream(template_form_path, tmpfile)
        tmpfile.close
      end
      FileUtils.touch(tempfile)
      FileUtils.copy_file(tempfile.path, stamped_template_path)

      if File.exist? stamped_template_path
        stamper = PdfStamper.new(stamped_template_path, form, current_loa)
        stamper.stamp_pdf
        pdftk.fill_form(stamped_template_path, generated_form_path, mapped_data, flatten: true)
        Common::FileHelpers.delete_file_if_exists(stamped_template_path)
        generated_form_path
      else
        raise "stamped template file does not exist: #{stamped_template_path}"
      end
    end

    private

    def mapped_data
      template = Rails.root.join('modules', 'simple_forms_api', 'app', 'form_mappings', "#{form_number}.json.erb").read
      b = binding
      b.local_variable_set(:data, form)
      result = ERB.new(template).result(b)
      JSON.parse(escape_json_string(result))
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
