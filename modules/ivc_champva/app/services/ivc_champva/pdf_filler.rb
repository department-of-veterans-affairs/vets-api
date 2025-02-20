# frozen_string_literal: true

require 'common/file_helpers'

module IvcChampva
  class PdfFiller
    attr_accessor :form, :form_number, :name, :uuid

    TEMPLATE_BASE = Rails.root.join('modules', 'ivc_champva', 'templates')

    def initialize(form_number:, form:, name: nil, uuid: nil)
      raise 'form_number is required' if form_number.blank?
      raise 'form needs a data attribute' unless form&.data

      @form = form
      @form_number = form_number
      @name = name || form_number
      @uuid = uuid
    end

    def generate(current_loa = nil)
      generated_form_path = Rails.root.join("tmp/#{@uuid}_#{name}-tmp.pdf").to_s
      stamped_template_path = Rails.root.join("tmp/#{@uuid}_#{name}-stamped.pdf").to_s

      tempfile = create_tempfile
      FileUtils.touch(tempfile)
      FileUtils.copy_file(tempfile.path, stamped_template_path)

      if File.exist? stamped_template_path
        begin
          PdfStamper.stamp_pdf(stamped_template_path, form, current_loa)
          pdftk = PdfForms.new(Settings.binaries.pdftk)
          pdftk.fill_form(stamped_template_path, generated_form_path, mapped_data, flatten: true)
          generated_form_path
        ensure
          Common::FileHelpers.delete_file_if_exists(stamped_template_path)
        end
      else
        raise "stamped template file does not exist: #{stamped_template_path}"
      end
    ensure
      tempfile&.close!
    end

    def create_tempfile
      # Tempfile workaround inspired by this:
      #   https://github.com/actions/runner-images/issues/4443#issuecomment-965391736
      template_form_path = "#{TEMPLATE_BASE}/#{form_number}.pdf"
      Tempfile.new(['', '.pdf'], Rails.root.join('tmp')).tap do |tmpfile|
        IO.copy_stream(template_form_path, tmpfile)
        tmpfile.flush
        tmpfile.close
      end
    end

    private

    def mapped_data
      template = Rails.root.join('modules', 'ivc_champva', 'app', 'form_mappings', "#{form_number}.json.erb").read
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
