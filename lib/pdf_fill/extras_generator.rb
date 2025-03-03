# frozen_string_literal: true

module PdfFill
  class ExtrasGenerator
    HEADER_FONT_SIZE = 14.5
    SUBHEADER_FONT_SIZE = 10.5

    attr_reader :extras_redesign

    def initialize(extras_redesign: false, form_name: nil, submit_date: nil, start_page: 1, sections: nil)
      @generate_blocks = []
      @extras_redesign = extras_redesign
      @form_name = form_name
      @submit_date = format_date(submit_date)
      @start_page = start_page
      @sections = sections
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
      unless text? || extras_redesign
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

    def populate_section_indices!
      return if @sections.blank?

      @generate_blocks.each do |generate_block|
        metadata = generate_block[:metadata]
        if metadata[:top_level_key].present?
          metadata[:section_index] = @sections.index { |sec| sec[:top_level_keys].include?(metadata[:top_level_key]) }
        end
      end
    end

    def sort_generate_blocks
      @generate_blocks.sort_by do |generate_block|
        metadata = generate_block[:metadata]
        [
          metadata[:section_index] || -1,
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
        location = [pdf.bounds.left, pdf.bounds.top]
        write_header_main(pdf, location, bound_width, HEADER_FONT_SIZE)
        if @submit_date.present?
          location[0] += bound_width
          write_header_submit_date(pdf, location, bound_width, HEADER_FONT_SIZE)
        end
        pdf.pad_top(2) { pdf.stroke_horizontal_rule }
      end
    end

    def add_page_numbers(pdf)
      pdf.number_pages('Page <page>',
                       start_count_at: @start_page,
                       at: [pdf.bounds.right - 50, 0],
                       align: :right,
                       size: 9)
    end

    def generate_pdf(file_path, generate_blocks)
      Prawn::Document.generate(file_path) do |pdf|
        set_font(pdf)
        set_header(pdf) if extras_redesign

        render_pdf_content(pdf, generate_blocks)
        add_page_numbers(pdf) if extras_redesign
      end
    end

    def render_new_section(pdf, section_index)
      return unless @extras_redesign && @sections.present?

      pdf.move_down(20)
      pdf.text(@sections[section_index][:label], { size: 14 })
    end

    def render_pdf_content(pdf, generate_blocks)
      current_section_index = nil
      box_height = 25
      pdf.bounding_box(
        [pdf.bounds.left, pdf.bounds.top - box_height],
        width: pdf.bounds.width,
        height: pdf.bounds.height - box_height
      ) do
        generate_blocks.each do |block|
          section_index = block[:metadata][:section_index]
          if section_index.present? && section_index != current_section_index
            render_new_section(pdf, section_index)
            current_section_index = section_index
          end
          block[:block].call(pdf)
        end
      end
    end

    def generate
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/extras_#{SecureRandom.uuid}.pdf"
      populate_section_indices!
      generate_blocks = sort_generate_blocks
      generate_pdf(file_path, generate_blocks)
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
        pdf.text("Submitted on VA.gov on #{@submit_date}",
                 align: :right,
                 valign: :bottom,
                 size: SUBHEADER_FONT_SIZE)
      end
    end

    # Formats the submit_date for the PDF header
    def format_date(date)
      return nil if date.blank?

      return "#{date['month']}-#{date['day']}-#{date['year']}" if date.is_a?(Hash)
      return date.strftime('%m-%d-%Y') if date.is_a?(Date)

      Date.parse(date).strftime('%m-%d-%Y')
    rescue
      Rails.logger.error("Error formatting submit date for PdfFill: #{date}")
      nil
    end
  end
end
