# frozen_string_literal: true

module PdfFill
  class ExtrasGeneratorV2 < ExtrasGenerator
    HEADER_FONT_SIZE = 14.5
    SUBHEADER_FONT_SIZE = 10.5
    FOOTER_FONT_SIZE = 9
    HEADER_FOOTER_BOUNDS_HEIGHT = 20
    LABEL_WIDTH = 91
    FREE_TEXT_QUESTION_WIDTH = 404
    MEAN_CHAR_WIDTH = 4.5
    HEADER_BODY_GAP = 25
    BODY_FOOTER_GAP = 27

    class Question
      attr_accessor :section_index, :overflow

      def initialize(question_text, metadata)
        @section_index = nil
        @number = metadata[:question_num]
        @text = question_text
        @subquestions = []
        @overflow = false
      end

      def numbered_label_markup
        prefix = @number.to_i == @number ? "#{@number}. " : ''
        "<h3>#{prefix}#{@text}</h3>"
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

      def format_value(value, format_options)
        value = value.to_s.gsub("\n", '<br/>')
        value = "<i>#{value}</i>" if value == 'no response'
        value = "<b>#{value}</b>" if format_options[:bold_value]
        value
      end

      def format_label(label, format_options)
        label = "<b>#{label}</b>" if format_options[:bold_label]
        label
      end

      def checklist_group?
        @subquestions.any? { |subq| subq[:metadata][:question_type] == 'checklist_group' }
      end

      def sorted_subquestions_markup
        if checklist_group?
          checklist_group_markup
        else
          tabular_subquestions_markup
        end
      end

      def checklist_group_markup
        sorted_subquestions.map do |subq|
          meta = subq[:metadata]
          checked = meta[:checked_values]&.include?(subq[:value].to_s) # nil if checked_values are absent
          if meta[:question_type] != 'checklist_group' || checked == false
            ''
          else
            text = subq[:metadata][:question_label]
            text = "#{text}: #{subq[:value]}" unless checked == true
            "<tr><td><ul><li>#{text}</li></ul></td></tr>"
          end
        end
      end

      def tabular_subquestions_markup
        if @subquestions.size == 1
          subq = @subquestions.first
          format_options = subq[:metadata][:format_options] || {}
          value = format_value(subq[:value], format_options)
          width = format_options[:question_width] || FREE_TEXT_QUESTION_WIDTH

          "<tr><td style='width:#{width}'>#{value}</td><td></td></tr>"
        else
          sorted_subquestions.map do |subq|
            metadata = subq[:metadata]
            format_options = metadata[:format_options] || {}

            label = metadata[:question_label].presence || metadata[:question_text]
            label = format_label(label, format_options)
            value = format_value(subq[:value], format_options)
            width = format_options[:label_width] || LABEL_WIDTH

            "<tr><td style='width:#{width}'>#{label}:</td><td>#{value}</td></tr>"
          end
        end
      end

      def should_render?
        sorted_subquestions.any?
      end

      def render(pdf, list_format: false)
        pdf.markup(numbered_label_markup) unless list_format
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

    class FreeTextQuestion < Question
      def render(pdf, list_format: false)
        pdf.markup(numbered_label_markup) unless list_format
        chunks = sorted_subquestions_markup
        chunks.flatten.each do |chunk|
          margin_bottom = chunk == Prawn::Text::NBSP ? 10 : 0
          pdf.markup(chunk, text: { margin_bottom: })
        end
      end

      def sorted_subquestions_markup
        @subquestions.map do |subq|
          format_options = subq[:metadata][:format_options] || {}
          width = format_options[:question_width] || FREE_TEXT_QUESTION_WIDTH

          split_into_lines(subq[:value].to_s, width).map do |chunk|
            if chunk == 'no response'
              "<i>#{chunk}</i>"
            elsif format_options[:bold_value]
              "<b>#{chunk}</b>"
            else
              chunk
            end
          end
        end
      end

      def split_into_lines(text, width) # rubocop:disable Metrics/MethodLength
        return ['no response'] if text.blank?

        # Approximate characters per line based on width
        chars_per_line = (width / MEAN_CHAR_WIDTH).to_i

        chunks = []
        paragraphs = text.to_s.split(/\n+/)
        paragraphs.each do |paragraph|
          if paragraph.length <= chars_per_line
            chunks << paragraph
          else
            current_line = ''

            paragraph.split(/\s+/).each do |word|
              if (current_line.length + word.length + 1) <= chars_per_line
                current_line += ' ' unless current_line.empty?
                current_line += word
              else
                chunks << current_line unless current_line.empty?
                current_line = word
              end
            end

            chunks << current_line unless current_line.empty?
          end

          # Add a No-Break Space as a separate chunk to represent paragraph break
          chunks << Prawn::Text::NBSP unless paragraph == paragraphs.last
        end

        chunks.empty? ? ['no response'] : chunks
      end
    end

    class CheckedDescriptionQuestion < Question
      attr_reader :description, :additional_info

      def initialize(question_text, metadata)
        super
        @description = nil
        @additional_info = nil
        @checked = false
      end

      def add_text(value, metadata)
        question = metadata[:question_label] || metadata[:question_text]
        format_options = metadata[:format_options] || {}
        case question
        when 'Description'
          @description = { value:, format_options: }
        when 'Additional Information'
          @additional_info = { value:, format_options: }
        when 'Checked'
          @checked = value == 'true'
        end
        @overflow ||= metadata.fetch(:overflow, true)
      end

      def should_render?
        @checked
      end

      def format_row(label_text, value, format_options)
        label = format_options[:bold_label] ? "<b>#{label_text}:</b>" : "#{label_text}:"

        if value.blank?
          value = '<i>no response</i>'
        elsif format_options[:bold_value]
          value = "<b>#{value}</b>"
        end

        width = format_options[:label_width] || LABEL_WIDTH
        "<tr><td style='width:#{width}'>#{label}</td><td>#{value}</td></tr>"
      end

      def render(pdf, list_format: false)
        return 0 unless should_render?

        pdf.markup(numbered_label_markup) unless list_format

        desc_options = @description&.dig(:format_options) || {}
        info_options = @additional_info&.dig(:format_options) || {}

        rows = [
          format_row('Description', @description&.dig(:value), desc_options),
          format_row('Additional Information', @additional_info&.dig(:value), info_options)
        ]

        pdf.markup([
          '<table>',
          rows,
          '</table>'
        ].flatten.join, text: { margin_bottom: 10 })
      end
    end

    class ListQuestion < Question
      attr_reader :items, :item_label

      def initialize(question_text, metadata)
        super
        @item_label = metadata[:item_label]
        @items = []
        @format_options = metadata[:format_options] || {}
      end

      def add_text(value, metadata)
        @overflow ||= metadata.fetch(:overflow, true)
        i = metadata[:i]

        # Create the appropriate question type if it doesn't exist yet
        if @items[i].nil?
          @items[i] = if metadata[:question_type] == 'checked_description'
                        CheckedDescriptionQuestion.new(nil, metadata)
                      else
                        Question.new(nil, metadata)
                      end
        end

        @items[i].add_text(value, metadata)
      end

      # Render the title of the list question
      def render_title(pdf)
        pdf.markup(numbered_label_markup)
      end

      # Render a single item from the list
      def render_item(pdf, item, index)
        if item.should_render?
          render_item_label(pdf, index)
          item.render(pdf, list_format: true)
        end
      end

      # Render the label for a list item
      def render_item_label(pdf, index)
        item_label = "<i>#{@item_label} #{index}</i>"
        item_label = "<b>#{item_label}</b>" if @format_options[:bold_item_label]
        pdf.markup(
          "<table><tr><th>#{item_label}</th></tr></table>",
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
        @items.compact.each.with_index(1) do |question, index|
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

        @items.compact.each.with_index(1) do |question, index|
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

    def placeholder_text
      'See attachment'
    end

    def set_font(pdf)
      register_source_sans_font(pdf)
      pdf.font('SourceSansPro')
      set_markup_options(pdf)
    end

    def add_text(value, metadata)
      question_num = metadata[:question_num]
      if @questions[question_num].blank?
        question_text = @question_key[question_num]

        @questions[question_num] =
          if metadata[:i].blank?
            case metadata[:question_type]
            when 'free_text'
              FreeTextQuestion.new(question_text, metadata)
            when 'checked_description'
              CheckedDescriptionQuestion.new(question_text, metadata)
            else
              Question.new(question_text, metadata)
            end
          else
            ListQuestion.new(question_text, metadata)
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
      temp_pdf = Prawn::Document.new(page_size: [612.0, 10_000.0])
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
      pdf.bounding_box(
        [pdf.bounds.left, pdf.bounds.top - HEADER_BODY_GAP],
        width: pdf.bounds.width,
        height: pdf.bounds.height - HEADER_BODY_GAP - BODY_FOOTER_GAP
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
      heights = block_heights.dig(block, :items).select(&:positive?)

      block.items
           .select { |item| item&.should_render? }
           .zip(heights) # pair each item with its height
           .each.with_index(1) do |(item, height), index|
             pdf.start_new_page unless will_fit_on_page?(pdf, height)
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
      pdf.repeat :all, dynamic: true do
        pdf.bounding_box(
          [pdf.bounds.left, pdf.bounds.bottom + HEADER_FOOTER_BOUNDS_HEIGHT],
          width: pdf.bounds.width,
          height: HEADER_FOOTER_BOUNDS_HEIGHT
        ) do
          pdf.markup("Page #{pdf.page_number + @start_page - 1}",
                     text: { align: :right, valign: :bottom, size: FOOTER_FONT_SIZE })
        end
      end
    end

    def add_footer(pdf)
      if @submit_date.present?
        ts = format_timestamp(@submit_date)
        txt = "Signed electronically and submitted via VA.gov at #{ts}. " \
              'Signee signed with an identity-verified account.'
        pdf.repeat :all do
          pdf.bounding_box(
            [pdf.bounds.left, pdf.bounds.bottom + HEADER_FOOTER_BOUNDS_HEIGHT],
            width: pdf.bounds.width,
            height: HEADER_FOOTER_BOUNDS_HEIGHT
          ) do
            pdf.markup(txt, text: { align: :left, valign: :bottom, size: FOOTER_FONT_SIZE })
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
          italic: Rails.root.join('lib', 'pdf_fill', 'fonts', 'SourceSans3-It.ttf'),
          bold_italic: Rails.root.join('lib', 'pdf_fill', 'fonts', 'SourceSans3-BoldItalic.ttf')
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
            padding: [1, 0, 1, 0],
            overflow: :shrink_to_fit
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
