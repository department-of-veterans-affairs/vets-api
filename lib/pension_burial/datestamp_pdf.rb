module PensionBurial
  class DatestampPdf
    def initialize(file, skip_date_on_stamp: false, append_to_stamp: nil)
      @file = file
      @skip_date_on_stamp = skip_date_on_stamp
      @append_to_stamp = append_to_stamp
    end

    def run(settings)
      in_path = get_file
      stamp_path = Common::FileHelpers.random_file_path
      generate_stamp(stamp_path, settings[:text], settings[:x], settings[:y], settings[:text_only])
      out_path = stamp(in_path, stamp_path)
    end

    def get_file
      Common::FileHelpers.generate_temp_file(@file.read)
    end

    def generate_stamp(stamp_path, text, x, y, text_only)
      unless text_only
        text += ' ' + I18n.l(DateTime.current, format: :pdf_stamp) unless @skip_date_on_stamp
        text += ('. ' + @append_to_stamp) if @append_to_stamp
      end

      Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
        pdf.draw_text text, at: [x, y], size: 10
      end
    rescue StandardError => e
      Rails.logger.error "Failed to generate datestamp file: #{e.message}"
      raise
    end

    def stamp(file_path, stamp_path)
      out_path = Common::FileHelpers.random_file_path
      PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, out_path)
      File.delete(file_path)
      File.delete(stamp_path)
      out_path
    rescue
      File.delete(out_path)
      raise
    end
  end
end
