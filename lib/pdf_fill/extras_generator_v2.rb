# frozen_string_literal: true

module PdfFill
  class ExtrasGeneratorV2 < ExtrasGenerator
    HEADER_FONT_SIZE = 14.5
    SUBHEADER_FONT_SIZE = 10.5
    FOOTER_FONT_SIZE = 9
    HEADER_FOOTER_BOUNDS_HEIGHT = 20

    attr_reader :question_key

    class Question
      attr_accessor :section_index, :overflow

      def initialize(question_text, metadata, table_width:)
        @section_index = nil
        @number = metadata[:question_num]
        @text = question_text
        @subquestions = []
        @overflow = false
        @table_width = table_width
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

      def sorted_subquestions_markup
        subq_rows = []

        sorted_subquestions.each do |subq|
          metadata = subq[:metadata]
          label = metadata[:question_label].presence || metadata[:question_text]
          value = subq[:value].to_s.gsub("\n", '<br/>')
          value = "<i>#{value}</i>" if value == 'no response'

          subq_rows << "<tr><td style='width:#{@table_width}'>#{label}:</td><td>#{value}</td></tr>"
        end

        subq_rows
      end

      def should_render?
        sorted_subquestions.any?
      end

      def render(pdf, list_format: false)
        pdf.markup("<h3>#{@number}. #{@text}</h3>") unless list_format
        pdf.markup(['<table>', sorted_subquestions_markup, '</table>'].flatten.join, text: { margin_bottom: 10 })
      end

      # Render content to a temporary PDF and measure the actual height
      def measure_actual_height(temp_pdf)
        return 0 unless should_render?

        # Save the current cursor position
        start_cursor = temp_pdf.cursor

        # Use the existing render method to render the content
        # For regular questions, we don't need any special parameters
        render(temp_pdf)

        # Calculate the actual height by measuring cursor movement
        start_cursor - temp_pdf.cursor
      end
    end

    class CheckedDescriptionQuestion < Question
      attr_reader :description, :additional_info

      def initialize(question_text, metadata, table_width:)
        super
        @description = nil
        @additional_info = nil
        @checked = false
      end

      def add_text(value, metadata)
        case metadata[:question_text]
        when 'Description'
          @description = value
        when 'Additional Information'
          @additional_info = value
        when 'Checked'
          @checked = value == 'true'
        end
        @overflow ||= metadata.fetch(:overflow, true)
      end

      def should_render?
        @checked
      end

      def render(pdf, list_format: false)
        return unless should_render?

        pdf.markup("<h3>#{@number}. #{@text}</h3>") unless list_format
        info = @additional_info.presence || '<i>no response</i>'
        pdf.markup([
          '<table>',
          "<tr><td style='width:#{@table_width}'><b>Description:</b></td><td><b>#{@description}</b></td></tr>",
          "<tr><td style='width:#{@table_width}'>Additional Information:</td><td>#{info}</td></tr>",
          '</table>'
        ].flatten.join, text: { margin_bottom: 10 })
      end
    end

    class ListQuestion < Question
      attr_reader :items, :item_label

      def initialize(question_text, metadata, table_width:)
        super
        @item_label = metadata[:item_label]
        @table_width = table_width
        @items = []
      end

      def add_text(value, metadata)
        @overflow ||= metadata.fetch(:overflow, true)
        i = metadata[:i]

        # Create the appropriate question type if it doesn't exist yet
        if @items[i].nil?
          @items[i] = if metadata[:question_type] == 'checked_description'
                        CheckedDescriptionQuestion.new(nil, metadata, table_width: @table_width)
                      else
                        Question.new(nil, metadata, table_width: @table_width)
                      end
        end

        @items[i].add_text(value, metadata)
      end

      # Render the title of the list question
      def render_title(pdf)
        pdf.markup("<h3>#{@number}. #{@text}</h3>")
      end

      # Render a single item from the list
      def render_item(pdf, item, index)
        render_item_label(pdf, index) if item.should_render?
        item.render(pdf, list_format: true)
      end

      # Render the label for a list item
      def render_item_label(pdf, index)
        pdf.markup(
          "<table><tr><th><i>#{@item_label} #{index}</i></th></tr></table>",
          table: {
            cell: {
              borders: [:bottom],
              border_width: 1,
              padding: [5, 0, 3.5, 0]
            }
          },
          text: { margin_bottom: -2 }
        )
      end

      def render(pdf)
        render_title(pdf)
        @items.each.with_index(1) do |question, index|
          render_item(pdf, question, index)
        end
      end

      def measure_title_height(temp_pdf)
        start_cursor = temp_pdf.cursor
        render_title(temp_pdf)
        start_cursor - temp_pdf.cursor
      end

      def measure_item_height(temp_pdf, item, index)
        start_cursor = temp_pdf.cursor
        render_item(temp_pdf, item, index)
        start_cursor - temp_pdf.cursor
      end

      # Measure heights of all components separately
      def measure_actual_height(temp_pdf)
        heights = { title: measure_title_height(temp_pdf) }
        heights[:items] = []

        @items.each.with_index(1) do |question, index|
          temp_pdf.start_new_page
          heights[:items] << measure_item_height(temp_pdf, question, index)
        end

        heights
      end
    end

    def initialize(options = {})
      @form_name              = options[:form_name]
      @submit_date            = options[:submit_date]
      @question_key           = options[:question_key]
      @start_page             = options[:start_page] || 1
      @sections               = options[:sections]
      @questions              = {}
      super()
    end

    def set_font(pdf)
      register_source_sans_font(pdf)
      pdf.font('SourceSansPro')
      set_markup_options(pdf)
    end

    def add_text(value, metadata)
      question_num = metadata[:question_num]
      if @questions[question_num].blank?
        question_data = @question_key[question_num]
        question_text = question_data[:text]
        table_width = question_data[:table_width]

        @questions[question_num] =
          if metadata[:i].blank?
            Question.new(question_text, metadata, table_width:)
          else
            ListQuestion.new(question_text, metadata, table_width:)
          end
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
      @questions.values.compact.any?(&:overflow)
    end

    def sort_generate_blocks
      populate_section_indices!
      @questions.keys.sort.map { |qnum| @questions[qnum] }.filter(&:overflow)
    end

    def measure_section_header_height(temp_pdf, section_index)
      return 0 if @sections.blank?

      start_cursor = temp_pdf.cursor
      temp_pdf.markup("<h2>#{@sections[section_index][:label]}</h2>")
      start_cursor - temp_pdf.cursor
    end

    def will_fit_on_page?(pdf, content_height)
      content_height <= pdf.cursor
    end

    def measure_content_heights(generate_blocks)
      temp_pdf = Prawn::Document.new
      set_font(temp_pdf)
      heights = {}.compare_by_identity

      measure_all_section_headers(temp_pdf, generate_blocks, heights)
      measure_all_blocks(temp_pdf, generate_blocks, heights)
      heights
    end

    def measure_all_section_headers(temp_pdf, generate_blocks, heights)
      heights[:sections] = generate_blocks
                           .map(&:section_index)
                           .compact
                           .uniq
                           .index_with { |idx| measure_section_header_height(temp_pdf, idx) }
    end

    def measure_all_blocks(temp_pdf, generate_blocks, heights)
      generate_blocks.each do |block|
        temp_pdf.start_new_page
        heights[block] = block.measure_actual_height(temp_pdf)
      end
    end

    def render_section_header_if_needed(pdf, section_index, current_section_index)
      if section_index.present? && section_index != current_section_index
        render_new_section(pdf, section_index)
        return section_index
      end
      current_section_index
    end

    def handle_regular_question_page_break(pdf, block, section_index, block_heights)
      block_height = block_heights[block]
      section_header_height = section_index.present? ? block_heights[:sections][section_index] : 0
      total_height = section_header_height + block_height

      unless will_fit_on_page?(pdf, total_height)
        pdf.start_new_page
        return true
      end

      false
    end

    def handle_list_title_page_break(pdf, block, section_index, block_heights)
      component_heights = block_heights[block]
      title_height = component_heights[:title]
      first_item_height = component_heights[:items].first if component_heights[:items].any?
      section_header_height = section_index.present? ? block_heights[:sections][section_index] : 0

      total_height = section_header_height + title_height + (first_item_height || 0)

      unless will_fit_on_page?(pdf, total_height)
        pdf.start_new_page
        return true
      end

      false
    end

    def render_pdf_content(pdf, generate_blocks)
      set_header(pdf)

      block_heights = measure_content_heights(generate_blocks)

      current_section_index = nil
      box_height = 25
      pdf.bounding_box(
        [pdf.bounds.left, pdf.bounds.top - box_height],
        width: pdf.bounds.width,
        height: pdf.bounds.height - box_height
      ) do
        generate_blocks.each do |block|
          section_index = block.section_index

          current_section_index = render_question_block(pdf, block, section_index, current_section_index, block_heights)
        end
      end
      add_footer(pdf)
      add_page_numbers(pdf)
    end

    def render_question_block(pdf, block, section_index, current_section_index, block_heights)
      if block.is_a?(ListQuestion)
        render_list_question(pdf, block, section_index, current_section_index, block_heights)
      else
        render_question(pdf, block, section_index, current_section_index, block_heights)
      end
    end

    def render_question(pdf, block, section_index, current_section_index, block_heights)
      page_break_inserted = handle_regular_question_page_break(pdf, block, section_index, block_heights)
      current_section_index = nil if page_break_inserted
      current_section_index = render_section_header_if_needed(pdf, section_index, current_section_index)
      block.render(pdf)

      current_section_index
    end

    def render_list_question(pdf, block, section_index, current_section_index, block_heights)
      page_break_inserted = handle_list_title_page_break(pdf, block, section_index, block_heights)
      current_section_index = nil if page_break_inserted
      current_section_index = render_section_header_if_needed(pdf, section_index, current_section_index)
      block.render_title(pdf)
      render_list_items(pdf, block, block_heights)

      current_section_index
    end

    def render_list_items(pdf, block, block_heights)
      block_heights = block_heights[block]
      block.items.select(&:should_render?).each.with_index(1) do |item, index|
        item_height = block_heights[:items][index - 1]
        pdf.start_new_page unless will_fit_on_page?(pdf, item_height)
        block.render_item(pdf, item, index)
      end
    end

    def render_new_section(pdf, section_index)
      return if @sections.blank?

      pdf.markup("<h2>#{@sections[section_index][:label]}</h2>")
    end

    def set_header(pdf)
      pdf.repeat :all do
        write_header_left(pdf, [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, HEADER_FOOTER_BOUNDS_HEIGHT)
        write_header_right(pdf, [pdf.bounds.left, pdf.bounds.top], pdf.bounds.width, HEADER_FOOTER_BOUNDS_HEIGHT)
        pdf.pad_top(2) { pdf.stroke_horizontal_rule }
      end
    end

    def write_header_left(pdf, location, bound_width, bound_height)
      pdf.bounding_box(location, width: bound_width, height: bound_height) do
        pdf.markup("<b>ATTACHMENT</b> to VA Form #{@form_name}",
                   text: { align: :left, valign: :bottom, size: HEADER_FONT_SIZE })
      end
    end

    def write_header_right(pdf, location, bound_width, bound_height)
      pdf.bounding_box(location, width: bound_width, height: bound_height) do
        pdf.markup('VA.gov Submission',
                   text: { align: :right, valign: :bottom, size: SUBHEADER_FONT_SIZE })
      end
    end

    def add_page_numbers(pdf)
      pdf.number_pages('Page <page>',
                       start_count_at: @start_page,
                       at: [pdf.bounds.right - 50, pdf.bounds.bottom],
                       align: :right,
                       size: FOOTER_FONT_SIZE)
    end

    def add_footer(pdf)
      if @submit_date.present?
        ts = format_timestamp(@submit_date)
        txt = "Signed electronically and submitted via VA.gov at #{ts}. " \
              'Signee signed with an identity-verified account.'
        pdf.repeat :all do
          pdf.bounding_box([pdf.bounds.left, pdf.bounds.bottom], width: pdf.bounds.width,
                                                                 height: HEADER_FOOTER_BOUNDS_HEIGHT) do
            pdf.markup(txt, text: { align: :left, size: FOOTER_FONT_SIZE })
          end
        end
      end
    end

    def format_timestamp(datetime)
      return nil if datetime.blank?

      "#{datetime.utc.strftime('%H:%M')} UTC #{datetime.utc.strftime('%Y-%m-%d')}"
    end

    def register_source_sans_font(pdf)
      pdf.font_families.update(
        'SourceSansPro' => {
          normal: Rails.root.join('lib', 'pdf_fill', 'fonts', 'SourceSans3-Regular.ttf'),
          bold: Rails.root.join('lib', 'pdf_fill', 'fonts', 'SourceSans3-Bold.ttf'),
          italic: Rails.root.join('lib', 'pdf_fill', 'fonts', 'SourceSans3-It.ttf')
        }
      )
    end

    def set_markup_options(pdf)
      pdf.markup_options = {
        heading2: { style: :normal, size: 13, margin_top: 12, margin_bottom: -4 },
        heading3: { style: :bold, size: 10.5, margin_top: 10, margin_bottom: -2 },
        table: {
          cell: {
            border_width: 0,
            padding: [1, 0, 1, 0]
          }
        },
        text: {
          leading: 0.5,
          size: 10.5
        },
        list: { bullet: { char: '✓', margin: 0 }, content: { margin: 4 }, vertical_margin: 0 }
      }
    end
  end
end
