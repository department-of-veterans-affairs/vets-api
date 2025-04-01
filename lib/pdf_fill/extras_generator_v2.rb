# frozen_string_literal: true

module PdfFill
  class ExtrasGeneratorV2 < ExtrasGenerator
    HEADER_FONT_SIZE = 14.5
    SUBHEADER_FONT_SIZE = 10.5
    FOOTER_FONT_SIZE = 9
    HEADER_FOOTER_BOUNDS_HEIGHT = 20

    def initialize(form_name: nil, submit_date: nil, start_page: 1, sections: nil)
      super()
      @form_name = form_name
      @submit_date = submit_date
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

    def set_font(pdf)
      register_source_sans_font(pdf)
      pdf.font('SourceSansPro')
      set_markup_options(pdf)
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
      add_footer(pdf)
      add_page_numbers(pdf)
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

    # Formats the timestamp for the PDF footer
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
        heading2: { style: :normal, size: 13 },
        heading3: { style: :bold, size: 10.5 },
        heading4: { style: :normal, size: 10.5 },
        table: {
          cell: {
            border_width: 0,
            padding: [2, 0, 2, 0]
          }
        },
        list: { bullet: { char: '✓', margin: 0 }, content: { margin: 4 }, vertical_margin: 0 }
      }
    end
  end
end
