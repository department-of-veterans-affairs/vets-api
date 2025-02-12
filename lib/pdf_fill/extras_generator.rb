# frozen_string_literal: true

module PdfFill
  class ExtrasGenerator
    attr_reader :extras_redesign

    def initialize(form_name: nil, submit_date: nil, extras_redesign: false)
      @generate_blocks = []
      @form_name = form_name
      @submit_date = submit_date
      @extras_redesign = extras_redesign
    end

    def create_block(value, metadata)
      lambda do |pdf|
        pdf.move_down(10)
        prefix = metadata[:question_num].to_s
        prefix += metadata[:question_suffix] if metadata[:question_suffix].present?
        prefix = "#{prefix}. #{metadata[:question_text].humanize}"
        i = metadata[:i]
        prefix += " Line #{i + 1}" if i.present?

        pdf.text("#{prefix}:", { style: extras_redesign ? :normal : :bold })
        pdf.text(value.to_s, { style: extras_redesign ? :bold : :normal })
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
          metadata[:question_suffix] || '',
          metadata[:question_text] || ''
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

    def set_header(pdf)
      pdf.repeat :all do
        bound_width = pdf.bounds.width / 2
        bound_height = 14.5
        location = [pdf.bounds.left, pdf.bounds.top]
        write_header_main(pdf, location, bound_width, bound_height)
        if @submit_date.present?
          location[0] += bound_width
          write_header_submit_date(pdf, location, bound_width, bound_height)
        end
        pdf.pad_top(2) { pdf.stroke_horizontal_rule }
      end
    end

    def generate
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/extras_#{SecureRandom.uuid}.pdf"
      generate_blocks = sort_generate_blocks
      Prawn::Document.generate(file_path) do |pdf|
        set_font(pdf)

        set_header(pdf) if extras_redesign

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

    def write_header_main(pdf, location, bound_width, bound_height)
      pdf.bounding_box(location, width: bound_width, height: bound_height) do
        pdf.text("<b>ATTACHMENT</b> to VA Form #{@form_name}",
                 align: :left,
                 valign: :bottom,
                 size: bound_height,
                 inline_format: true)
      end
    end

    def write_header_submit_date(pdf, location, bound_width, bound_height)
      pdf.bounding_box(location, width: bound_width, height: bound_height) do
        formatted = Date.strptime(@submit_date, '%Y-%m-%d').strftime('%m-%d-%Y')
        pdf.text("Submitted on VA.gov on #{formatted}",
                 align: :right,
                 valign: :bottom,
                 size: 10.5)
      end
    end
  end
end
