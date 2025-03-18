# frozen_string_literal: true

module PdfFill
  class ExtrasGeneratorV2 < ExtrasGenerator
    HEADER_FONT_SIZE = 14.5
    SUBHEADER_FONT_SIZE = 10.5

    def initialize(form_name: nil, submit_date: nil, start_page: 1, sections: nil)
      super()
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

        pdf.text("#{prefix}:", { style: :normal })
        pdf.text(value.to_s, { style: :bold })
      end
    end

    def add_text(value, metadata)
      @generate_blocks << {
        metadata:,
        block: create_block(value, metadata)
      }
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

    def generate_pdf(file_path)
      populate_section_indices!
      generate_blocks = sort_generate_blocks
      Prawn::Document.generate(file_path) do |pdf|
        set_font(pdf)
        set_header(pdf)

        render_pdf_content(pdf, generate_blocks)
        add_page_numbers(pdf)
      end
    end

    def render_new_section(pdf, section_index)
      return if @sections.blank?

      pdf.move_down(20)
      pdf.text(@sections[section_index][:label], { size: 14 })
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
