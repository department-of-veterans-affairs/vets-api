# frozen_string_literal: true

module PdfFill
  class ExtrasGeneratorV2 < ExtrasGenerator
    HEADER_FONT_SIZE = 14.5
    SUBHEADER_FONT_SIZE = 10.5

    class Question
      attr_accessor :section_index, :overflow

      def initialize(metadata)
        @section_index = nil
        @number = metadata[:question_num]
        @subquestions = []
        @overflow = false
      end

      def add_text(value, metadata)
        @subquestions << { value:, metadata: }
        @overflow ||= metadata.fetch(:overflow, true)
      end

      def sorted_subquestions
        @subquestions.sort_by do |subq|
          [subq[:metadata][:question_suffix] || '', subq[:metadata][:question_text] || '']
        end
      end

      def render(pdf, list_format: false)
        sorted_subquestions.each do |subq|
          value = subq[:value]
          metadata = subq[:metadata]
          prefix = "#{metadata[:question_num]}#{metadata[:question_suffix]}. #{metadata[:question_text].humanize}"
          i = metadata[:i]
          prefix += " Line #{i + 1}" if i.present?

          if list_format
            pdf.text("#{prefix}: <b>#{value}</b>", inline_format: true)
          else
            pdf.move_down(10)
            pdf.text("#{prefix}:", { style: :normal })
            pdf.text(value.to_s, { style: :bold })
          end
        end
      end
    end

    class ListQuestion < Question
      def initialize(metadata)
        super
        @items = []
        @array_question_text = metadata[:array_question_text]
      end

      def add_text(value, metadata)
        @overflow ||= metadata.fetch(:overflow, true)
        i = metadata[:i]
        @items[i] ||= Question.new(metadata)
        @items[i].add_text(value, metadata)
      end

      def render(pdf)
        pdf.move_down(10)
        pdf.text("#{@number}. #{@array_question_text}", style: :bold)
        @items.each do |question|
          pdf.move_down(10)
          question.render(pdf, list_format: true)
        end
      end
    end

    def initialize(form_name: nil, submit_date: nil, start_page: 1, sections: nil)
      super()
      @form_name = form_name
      @submit_date = format_date(submit_date)
      @start_page = start_page
      @sections = sections
      @questions = {}
    end

    def add_text(value, metadata)
      question_num = metadata[:question_num]
      if @questions[question_num].blank?
        @questions[question_num] = (metadata[:i].blank? ? Question : ListQuestion).new(metadata)
      end
      @questions[question_num].add_text(value, metadata)
    end

    def populate_section_indices!
      return if @sections.blank?

      @questions.each do |num, question|
        question.section_index = @sections.index { |sec| sec[:question_nums].include?(num) }
      end
    end

    def text?
      @questions.compact.any?(&:overflow)
    end

    def sort_generate_blocks
      populate_section_indices!
      @questions.keys.sort.map { |qnum| @questions[qnum] }.filter(&:overflow)
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
          section_index = block.section_index
          if section_index.present? && section_index != current_section_index
            render_new_section(pdf, section_index)
            current_section_index = section_index
          end
          block.render(pdf)
        end
      end
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
