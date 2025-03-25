# frozen_string_literal: true

module PdfFill
  class ExtrasGeneratorV2 < ExtrasGenerator
    HEADER_FONT_SIZE = 14.5
    SUBHEADER_FONT_SIZE = 10.5
    FOOTER_FONT_SIZE = 9

    def initialize(form_name: nil, submit_date: nil, start_page: 1, sections: nil)
      super()
      @form_name = form_name
      @submit_date = submit_date
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

    def sort_generate_blocks
      populate_section_indices!
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

    def render_pdf_content(pdf, generate_blocks)
      set_header(pdf)

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
      add_footer(pdf)
      add_page_numbers(pdf)
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
        location[0] += bound_width
        write_submission_header(pdf, location, bound_width, HEADER_FONT_SIZE)
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

    def write_submission_header(pdf, location, bound_width, bound_height)
      pdf.bounding_box(location, width: bound_width, height: bound_height) do
        pdf.text('VA.gov Submission',
                 align: :right,
                 valign: :bottom,
                 size: SUBHEADER_FONT_SIZE)
      end
    end

    def add_footer(pdf)
      if @submit_date
        pdf.repeat :all do
          pdf.bounding_box([pdf.bounds.left, pdf.bounds.bottom], width: pdf.bounds.width, height: FOOTER_FONT_SIZE) do
            ts = format_timestamp(@submit_date)
            pdf.text(
              "Signed electronically and submitted via VA.gov at #{ts}. " \
              'Signee signed with an identify-verified account.',
              align: :left,
              size: FOOTER_FONT_SIZE
            )
          end
        end
      end
    end

    # Formats the timestamp for the PDF footer
    def format_timestamp(datetime)
      return nil if datetime.blank?

      "#{datetime.utc.strftime('%H:%M')} UTC #{datetime.utc.strftime('%Y-%m-%d')}"
    end
  end
end
