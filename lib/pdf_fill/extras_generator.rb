# frozen_string_literal: true
module PdfFill
  class ExtrasGenerator
    def initialize
      @generate_blocks = []
    end

    def add_text(metadata, value)
      unless text?
        @generate_blocks << lambda do |pdf|
          pdf.text('Additional Information', size: 16, style: :bold)
        end
      end

      @generate_blocks << {
        metadata: metadata,
        block: lambda do |pdf|
          pdf.move_down(10)
          prefix = metadata[:question_num]
          prefix += metadata[:question_suffix] if metadata[:question_suffix].present?
          prefix = "#{prefix}. #{question_text}"
          i = metadata[:i]
          prefix += " Line #{i + 1}" if i.present?

          pdf.text("#{prefix}:", style: :bold)
          pdf.text(value.to_s, style: :normal)
        end
      }
    end

    def text?
      @generate_blocks.size.positive?
    end

    def generate
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/extras_#{SecureRandom.uuid}.pdf"
      generate_blocks = @generate_blocks

      Prawn::Document.generate(file_path) do |pdf|
        box_height = 25
        pdf.bounding_box(
          [pdf.bounds.left, pdf.bounds.top - box_height],
          width: pdf.bounds.width,
          height: pdf.bounds.height - box_height
        ) do
          generate_blocks.each do |block|
            block.call(pdf)
          end
        end
      end

      file_path
    end
  end
end
