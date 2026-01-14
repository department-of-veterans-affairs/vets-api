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

    def generate(current_loa = nil, timestamp: Time.current)
      generated_form_path, stamped_template_path = prepare_to_generate_pdf

      if File.exist?(stamped_template_path)
        # 1) Fill base PDF (no stamping yet)
        generated_form_path = fill_and_generate_pdf(generated_form_path, stamped_template_path)

        # 2) Merge overflow (if any) using the same canonical timestamp
        final_path = if form.respond_to?(:overflow_pdf)
                       merge_overflow_if_needed(generated_form_path, timestamp)
                     else
                       generated_form_path
                     end

        # 3) Stamp once, at the end, on the final output for consistent stamping
        stamp_final_pdf(final_path, current_loa, timestamp)
      else
        raise "stamped template file does not exist: #{stamped_template_path}"
      end
    end

    private

    # Prepares paths and copies the base template to a "stamped" working file
    # Note: We keep the "-stamped.pdf" suffix to satisfy existing specs and indicate this is the stampable copy,
    # even though stamping is performed at the end on the final merged output.
    def prepare_to_generate_pdf
      generated_form_path = Rails.root.join("tmp/#{name}-#{SecureRandom.hex}-tmp.pdf").to_s
      stamped_template_path = Rails.root.join("tmp/#{name}-#{SecureRandom.hex}-stamped.pdf").to_s

      copy_from_tempfile(stamped_template_path)

      [generated_form_path, stamped_template_path]
    end

    def copy_from_tempfile(stamped_template_path)
      tempfile = create_tempfile
      FileUtils.touch(tempfile)
      FileUtils.copy_file(tempfile.path, stamped_template_path)
    end

    def create_tempfile
      template_form_path = "#{TEMPLATE_BASE}/#{form_number}.pdf"
      Tempfile.new(['', '.pdf'], Rails.root.join('tmp')).tap do |tmpfile|
        IO.copy_stream(template_form_path, tmpfile)
        tmpfile.close
      end
    end

    # Final stamping pass on the merged (or base) PDF using a single canonical timestamp
    def stamp_final_pdf(final_pdf_path, current_loa, timestamp)
      stamper = PdfStamper.new(stamped_template_path: final_pdf_path, form:, current_loa:, timestamp:)
      stamper.stamp_pdf
      final_pdf_path
    end

    # Fills the base PDF using pdftk and removes the working stamped template copy
    def fill_and_generate_pdf(generated_form_path, stamped_template_path)
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      pdftk.fill_form(stamped_template_path, generated_form_path, mapped_data, flatten: true)
      Common::FileHelpers.delete_file_if_exists(stamped_template_path)
      generated_form_path
    end

    # Merges overflow pages if the form provides them; on failure, returns the original filled PDF
    def merge_overflow_if_needed(filled_pdf_path, timestamp)
      overflow_pdf = form.overflow_pdf(timestamp)
      return filled_pdf_path if overflow_pdf.blank?

      merge_with_overflow(filled_pdf_path, overflow_pdf)
    rescue StandardError => e
      Rails.logger.error("Failed to merge overflow PDF: #{e.message}\n#{e.backtrace&.join("\n")}")
      FileUtils.rm_f(overflow_pdf) if overflow_pdf && File.exist?(overflow_pdf)
      filled_pdf_path
    end

    def merge_with_overflow(filled_pdf_path, overflow_pdf)
      merged_path = filled_pdf_path.sub(/\.pdf\z/, "_with_overflow_#{SecureRandom.hex}.pdf")

      PdfFill::Filler.merge_pdfs(filled_pdf_path, overflow_pdf, merged_path)
      # Cleanup temporary files
      FileUtils.rm_f(overflow_pdf)
      FileUtils.rm_f(filled_pdf_path)

      merged_path
    end

    def mapped_data
      template = Rails.root.join('modules', 'simple_forms_api', 'app', 'form_mappings', "#{form_number}.json.erb").read
      result = ERB.new(template).result_with_hash(form: form)
      JSON.parse(escape_json_string(result))
    end

    def escape_json_string(str)
      # Remove control characters that will break the JSON parser:
      # \u0000-\u001f: ASCII control chars (null, tab, LF, CR, etc)
      # \u0080-\u009f: Latin-1 supplement control chars
      # \u2000-\u201f: various Unicode spacing/dashes/quotes that can be problematic
      str.gsub(/[\u0000-\u001f\u0080-\u009f\u2000-\u201f]/, ' ')
    end
  end
end