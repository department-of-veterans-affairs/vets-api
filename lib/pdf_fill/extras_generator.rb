# frozen_string_literal: true

module PdfFill
  class ExtrasGenerator
    def initialize
      @generate_blocks = []
    end

    def create_block(value, metadata)
      lambda do |pdf|
        pdf.move_down(10)
        prefix = metadata[:question_num].to_s
        prefix += metadata[:question_suffix] if metadata[:question_suffix].present?
        prefix = "#{prefix}. #{metadata[:question_text].humanize}"
        i = metadata[:i]
        prefix += " Line #{i + 1}" if i.present?

        pdf.text("#{prefix}:", style: :bold)
        pdf.text(value.to_s, style: :normal)
      end
    end

    def add_text(value, metadata)
      unless text?
        @generate_blocks << {
          metadata: {},
          block: lambda do |pdf|
            pdf.text('Additional Information', size: 16, style: :bold)
          end
        }
      end

      @generate_blocks << {
        metadata:,
        block: create_block(value, metadata)
      }
    end

    def text?
      @generate_blocks.size.positive?
    end

    def sort_generate_blocks
      @generate_blocks.sort_by do |generate_block|
        metadata = generate_block[:metadata]
        [
          metadata[:question_num] || -1,
          metadata[:i] || 99_999,
          metadata[:question_suffix] || -1,
          metadata[:question_text]
        ]
      end
    end

    def set_font(pdf)
      pdf.font_families.update(
        'Roboto' => {
          normal: Rails.root.join('lib', 'pdf_fill', 'fonts', 'Roboto-Regular.ttf'),
          bold: Rails.root.join('lib', 'pdf_fill', 'fonts', 'Roboto-Bold.ttf')
        }
      )
      pdf.font('Roboto')
    end

    def generate
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/extras_#{SecureRandom.uuid}.pdf"
      generate_blocks = sort_generate_blocks
      Prawn::Document.generate(file_path) do |pdf|
        set_font(pdf)

        box_height = 25
        pdf.bounding_box(
          [pdf.bounds.left, pdf.bounds.top - box_height],
          width: pdf.bounds.width,
          height: pdf.bounds.height - box_height
        ) do
          generate_blocks.each do |block|
            block[:block].call(pdf)
          end
        end
      end

      file_path
    end
  end
end
