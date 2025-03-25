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
      @questions = {}
    end

    def render_question(pdf, question)
      sorted_subquestions = question[:subquestions].sort_by do |subq|
        metadata = subq[:metadata]
        [metadata[:i] || 99_999, metadata[:question_suffix] || '', metadata[:question_text] || '']
      end
      sorted_subquestions.each do |subq|
        value = subq[:value]
        metadata = subq[:metadata]
        pdf.move_down(10)
        prefix = metadata[:question_num].to_s
        prefix += metadata[:question_suffix] if metadata[:question_suffix].present?
        prefix = "#{prefix}. #{metadata[:question_text].humanize}"
        i = metadata[:i]
        prefix += " Line #{i + 1}" if i.present?

        pdf.markup("<h4>#{prefix}:</h4>")
        formatted_value = value.gsub("\n", '<br/>')
        pdf.markup("<b>#{formatted_value}</b>")
      end
    end

    def add_text(value, metadata)
      question_num = metadata[:question_num]
      question = (@questions[question_num] ||= { subquestions: [], overflow: false })
      question[:subquestions] << { value:, metadata: }
      question[:overflow] ||= metadata.fetch(:overflow, true)
    end

    def populate_section_indices!
      return if @sections.blank?

      @questions.each do |num, question|
        question[:section_index] = @sections.index { |sec| sec[:question_nums].include?(num) }
      end
    end

    def sort_generate_blocks
      populate_section_indices!
      @questions.keys.sort.map { |qnum| @questions[qnum] }.filter { |question| question[:overflow] }
    end

    def render_pdf_content(pdf, generate_blocks)
      setup_pdf(pdf)
      set_header(pdf)

      current_section_index = nil
      box_height = 25
      pdf.bounding_box(
        [pdf.bounds.left, pdf.bounds.top - box_height],
        width: pdf.bounds.width,
        height: pdf.bounds.height - box_height
      ) do
        generate_blocks.each do |block|
          section_index = block[:section_index]
          if section_index.present? && section_index != current_section_index
            render_new_section(pdf, section_index)
            current_section_index = section_index
          end
          render_question(pdf, block)
        end
      end
      add_page_numbers(pdf)
    end

    def render_new_section(pdf, section_index)
      return if @sections.blank?

      pdf.markup("<h2>#{@sections[section_index][:label]}</h2>")
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
        pdf.stroke_horizontal_rule
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
        pdf.markup("<b>ATTACHMENT</b> to VA Form #{@form_name}",
                   text: { align: :left, valign: :bottom, size: bound_height })
      end
    end

    def write_header_submit_date(pdf, location, bound_width, bound_height)
      pdf.bounding_box(location, width: bound_width, height: bound_height) do
        pdf.markup("Submitted on VA.gov on #{@submit_date}",
                   text: { align: :right, valign: :bottom, size: SUBHEADER_FONT_SIZE })
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
