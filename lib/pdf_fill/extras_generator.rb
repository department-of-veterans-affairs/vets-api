# frozen_string_literal: true
module PdfFill
  class ExtrasGenerator
    def initialize
      @generate_blocks = []
    end

    def add_text(prefix, text)
      unless text?
        @generate_blocks << lambda do |pdf|
          pdf.text('Additional Information', size: 16, style: :bold)
        end
      end

      @generate_blocks << lambda do |pdf|
        pdf.move_down(10)
        pdf.text("#{prefix}:", style: :bold)

        pdf.text(text.to_s, style: :normal)
      end
    end

    def text?
      @generate_blocks.size.positive?
    end

    def generate
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/extras_#{Time.zone.now}.pdf"
      generate_blocks = @generate_blocks

      Prawn::Document.generate(file_path) do |pdf|
        generate_blocks.each do |block|
          block.call(pdf)
        end
      end

      file_path
    end
  end
end
