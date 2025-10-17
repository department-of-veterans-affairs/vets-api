# frozen_string_literal: true

require 'prawn/table'

module DecisionReviews
  class NotificationEmailToPdfService
    BODY_TEXT_SIZE = 11
    GRAY_BOX_HEIGHT = 185
    BLOCKQUOTE_INDENT = 40
    CONTENT_INDENT = 40
    TEXT_LEADING = 2.5
    SPACE_SINGLE_HALF = 4
    SPACE_SINGLE = 8
    SPACE_SINGLE_HALF = 12
    SPACE_DOUBLE = 16

    LINK_COLOR = '004795'

    HEADER_UNDERLINE = /^={3,}/
    DR_EMAIL_HEADER = /^Decision Reviews Notification Email$/
    METADATA_HEADERS = [/^Email Metadata:$/, /^Email Content:$/].freeze
    SECTION_DIVIDER = /^-{3,}/
    BLOCKQUOTE_PATTERN = /^>\s*(.*)/
    FULL_LINE_BOLDED_TEXT = /^\*\*(.+?)\*\*$/
    INLINE_BOLDED_TEXT = /(\*\*.*?\*\*)/
    REGULAR_LINK_PATTERN = /\[(.+?)\]\((.+?)\)/
    ACTION_LINK_PATTERN = /^\(action-link\)\[(.+?)\]\((.+?)\)/
    HORIZ_RULE_PATTERN = %r{<hr\s*/?>}i
    METADATA_PATTERN = /^(To|Subject|Email Sent Date|Original Submission Date|Evidence Filename):/
    ADDRESS_PATTERN = /^\(address\)(.+)$/
    FOOTER_SEPARATOR = /^---$/

    def initialize(email_content:, email_subject:, email_address:, sent_date:, submission_date:, first_name:,
                   evidence_filename: nil)
      @email_content = email_content
      @email_subject = email_subject
      @email_address = email_address
      @sent_date = sent_date
      @submission_date = submission_date
      @first_name = first_name
      @evidence_filename = evidence_filename
    end

    def generate_pdf
      pdf_content = build_pdf_content
      generate_pdf_file(pdf_content)
    end

    def build_pdf_content
      # Replace redacted fields in email content with personalization data
      personalized_content = replace_redacted_fields(@email_content)

      content = <<~CONTENT
        Decision Reviews Notification Email
        ==================================

        Email Metadata:
        ---------------
        To: #{@email_address}
        Subject: #{@email_subject}
        Email Sent Date: #{@sent_date.strftime('%B %d, %Y at %I:%M %p %Z')}
        Original Submission Date: #{@submission_date.strftime('%B %d, %Y at %I:%M %p %Z')}
      CONTENT

      content += "Evidence Filename: #{@evidence_filename}\n" if @evidence_filename

      content += <<~CONTENT

        Email Content:
        --------------
        #{personalized_content}

        ---
        This PDF was generated from a VA notification email sent via VA Notify service.
      CONTENT

      content
    end

    # Replace <redacted> placeholders with actual personalization values
    def replace_redacted_fields(content)
      # 1. Replace the first <redacted> after "Dear" with first name
      content = content.sub(/Dear\s+<redacted>/i, "Dear #{@first_name}")

      if @evidence_filename
        content = content.gsub(
          /(>\s*##\s*Here's the file name of the document we need\s*\n\s*>\s*)<redacted>/im
        ) { "#{Regexp.last_match(1)}#{@evidence_filename}" }
      end

      # 3. Replace any remaining <redacted> fields with formatted submission date
      formatted_submission_date = @submission_date.strftime('%B %d, %Y')
      content.gsub('<redacted>', formatted_submission_date)
    end

    def generate_pdf_file(content)
      # Create temporary file with unique name
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/dr_email_#{generate_document_id}.pdf"

      # Generate PDF and write to file in binary mode
      pdf_binary = convert_to_pdf(content)
      File.binwrite(file_path, pdf_binary)

      file_path
    end

    def convert_to_pdf(content)
      Prawn::Document.new(page_size: 'LETTER', margin: 50) do |pdf|
        pdf.font_families.update('Helvetica' => {
                                   normal: 'Helvetica',
                                   bold: 'Helvetica-Bold'
                                 })
        pdf.font 'Helvetica'
        pdf.fill_color '323A45'

        add_header(pdf)

        pdf.indent(CONTENT_INDENT) do
          add_formatted_content(pdf, content)
        end

        pdf.move_down 40

        add_footer(pdf)
      end.render
    end

    def self.heading_pattern(level)
      /^\s*(?:<\s*)?#{'\#' * level}(?!#)\s*(.+)/
    end

    H1_PATTERN = heading_pattern(1)
    H2_PATTERN = heading_pattern(2)
    H3_PATTERN = heading_pattern(3)

    def create_va_logo_header(pdf)
      header_top = pdf.cursor

      pdf.canvas do
        pdf.fill_color '112E51'
        pdf.fill_rectangle [0, pdf.bounds.absolute_top], pdf.bounds.absolute_right, 60
      end

      pdf.fill_color '323A45'

      pdf.image 'modules/decision_reviews/spec/fixtures/header-logo.png',
                at: [CONTENT_INDENT, pdf.bounds.absolute_top - 12],
                width: 175,
                height: 39

      pdf.move_cursor_to header_top - CONTENT_INDENT
      pdf.move_down SPACE_DOUBLE
    end

    def format_blockquote(pdf, text)
      pdf.indent(BLOCKQUOTE_INDENT) do
        text.split("\n").each do |line|
          pdf.move_down SPACE_DOUBLE if line.strip.empty?

          add_formatted_content(pdf, line)
        end
      end
    end

    # We want the height of the gray box to flex depending on the
    # height of the text content, so we create a temporary Prawn PDF
    # and render the text to measure there
    def measure_height_of_text_content(text)
      temp_pdf = Prawn::Document.new(page_size: 'LETTER', margin: 50)
      temp_pdf.font 'Helvetica', size: BODY_TEXT_SIZE

      temp_pdf.indent(CONTENT_INDENT) do
        temp_start = temp_pdf.cursor
        temp_pdf.move_down SPACE_DOUBLE

        temp_pdf.bounding_box([0, temp_pdf.cursor], width: temp_pdf.bounds.width - 60) do
          format_blockquote(temp_pdf, text)
        end

        temp_pdf.move_down SPACE_DOUBLE
        final_cursor = temp_pdf.cursor
        temp_start - final_cursor
      end
    end

    def create_gray_section(pdf, text)
      content_height = measure_height_of_text_content(text)

      # Check if we need a new page (need at least the content height + some padding)
      pdf.start_new_page if pdf.cursor < content_height + 40
      start_y = pdf.cursor

      # Draw gray rectangle
      pdf.fill_color 'F1F1F1'
      pdf.fill_rectangle [20, start_y],
                         pdf.bounds.width - 60,
                         content_height

      # Reset color for text
      pdf.fill_color '323A45'

      pdf.move_down SPACE_DOUBLE

      # Render text (on top of rectangle)
      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width - 60) do
        format_blockquote(pdf, text)
      end

      pdf.move_down SPACE_DOUBLE
    end

    def add_header(pdf)
      create_va_logo_header(pdf)

      pdf.text 'Department of Veterans Affairs',
               align: :center,
               size: 16,
               style: :bold

      pdf.move_down SPACE_SINGLE_HALF

      pdf.text 'Decision Reviews Notification Email Archive',
               align: :center,
               size: 12

      format_section_divider(pdf, SPACE_SINGLE, SPACE_DOUBLE)
    end

    def format_dr_email_header(pdf, line)
      pdf.font 'Helvetica-Bold', size: 18
      pdf.text line,
               align: :center,
               style: :bold
      pdf.move_down SPACE_DOUBLE
    end

    def format_metadata_headers(pdf, line)
      pdf.move_down SPACE_SINGLE
      pdf.font 'Helvetica-Bold', size: BODY_TEXT_SIZE
      pdf.text line,
               style: :bold
      pdf.move_down SPACE_SINGLE
    end

    def format_heading(pdf, text, level:)
      sizes = { h1: 24, h2: 18, h3: 14 }
      leadings = { h1: 1.75, h2: 1.25, h3: 1.0 }
      spacing = { h1: 0, h2: SPACE_SINGLE_HALF, h3: SPACE_SINGLE_HALF }

      pdf.move_down SPACE_DOUBLE if level == :h1

      pdf.text text,
               size: sizes[level],
               leading: leadings[level],
               style: :bold

      pdf.move_down spacing[level]
    end

    def format_links(pdf, link_text, link_url, bold: false, **options)
      styles = options[:styles] || (bold ? %i[underline bold] : [:underline])
      color = options[:color] || LINK_COLOR

      pdf.formatted_text [{
        text: link_text,
        color:,
        link: link_url,
        styles:
      }]
    end

    def format_action_links(pdf, link_text, link_url)
      start_y = pdf.cursor

      pdf.bounding_box([0, start_y], width: 20, height: 20) do
        pdf.image 'modules/decision_reviews/spec/fixtures/action-link-arrow.png',
                  width: 16,
                  height: 16,
                  position: :left
      end

      pdf.bounding_box([20, start_y - 4], width: pdf.bounds.width - 20, height: 20) do
        format_links(pdf, link_text, link_url, bold: true)
      end
    end

    def format_metadata_text(pdf, key, value)
      pdf.text "#{key}:",
               size: BODY_TEXT_SIZE,
               style: :bold,
               inline_format: true

      if value
        pdf.text value.strip,
                 size: BODY_TEXT_SIZE,
                 style: :normal
      end

      pdf.move_down SPACE_SINGLE_HALF
    end

    # Handles bolding and links within sentences
    def parse_inline_formatting(text)
      fragments = []
      last_pos = 0

      # Scan for all bold and link matches in order
      text.scan(/\*\*(.+?)\*\*|\[(.+?)\]\((.+?)\)/) do
        match = Regexp.last_match
        match_start = match.begin(0)
        match_end = match.end(0)

        # Add any text before this match
        fragments << { text: text[last_pos...match_start] } if match_start > last_pos

        # Add the matched element
        fragments << if match[1] # Bold text (first capture group)
                       { text: match[1], styles: [:bold] }
                     else # Link (second and third capture groups, text and URL)
                       {
                         text: match[2],
                         color: LINK_COLOR,
                         link: match[3],
                         styles: [:underline]
                       }
                     end

        last_pos = match_end
      end

      # Add any remaining text after the last match
      fragments << { text: text[last_pos..] } if last_pos < text.length

      fragments
    end

    # Handles normal paragraphs, empty lines, and inline formatting
    def format_paragraph_content(pdf, line)
      if line.strip.empty?
        pdf.move_down SPACE_SINGLE_HALF
      elsif line.include?('**') || line.include?('[')
        fragments = parse_inline_formatting(line.strip)
        pdf.formatted_text fragments,
                           size: BODY_TEXT_SIZE,
                           leading: TEXT_LEADING
      else
        pdf.font 'Helvetica'
        pdf.text line.strip,
                 size: BODY_TEXT_SIZE,
                 leading: TEXT_LEADING
      end
    end

    def format_address_block(pdf, address_text)
      address_lines = address_text.split('|').map(&:strip)

      address_lines.each do |address_line|
        pdf.text address_line,
                 size: BODY_TEXT_SIZE,
                 leading: TEXT_LEADING
      end
    end

    def format_section_divider(pdf, top_space, bottom_space)
      pdf.move_down top_space
      pdf.stroke_color 'BFC1C3'
      pdf.line_width 0.5
      pdf.stroke_horizontal_rule

      # Reset stroke color and line width after drawing the horizontal line
      pdf.stroke_color '000000'
      pdf.line_width 1

      pdf.move_down bottom_space
    end

    def add_formatted_content(pdf, content)
      lines = content.split("\n")
      i = 0

      while i < lines.length
        line = lines[i]

        case line
        when HEADER_UNDERLINE
          # Skip underline characters, we'll format headers differently
        when DR_EMAIL_HEADER
          format_dr_email_header(pdf, line)
        when *METADATA_HEADERS
          format_metadata_headers(pdf, line)
        when H1_PATTERN
          header_text = Regexp.last_match(1).strip
          format_heading(pdf, header_text, level: :h1)
        when H2_PATTERN
          header_text = Regexp.last_match(1).strip
          format_heading(pdf, header_text, level: :h2)
        when H3_PATTERN
          header_text = Regexp.last_match(1).strip
          format_heading(pdf, header_text, level: :h3)
        when ACTION_LINK_PATTERN
          link_text = Regexp.last_match(1)
          link_url = Regexp.last_match(2)
          format_action_links(pdf, link_text, link_url)
        when METADATA_PATTERN
          # Format metadata as key-value pairs
          key, value = line.split(':', 2)
          format_metadata_text(pdf, key, value)
        when ADDRESS_PATTERN
          address_text = Regexp.last_match(1)
          format_address_block(pdf, address_text)
        when BLOCKQUOTE_PATTERN
          blockquote_lines = []

          while i < lines.length && lines[i] =~ BLOCKQUOTE_PATTERN
            blockquote_lines << Regexp.last_match(1) # Capture text after '>'
            i += 1
          end

          i -= 1 # Back up one since the outer loop will increment

          blockquote_text = blockquote_lines.join("\n")
          create_gray_section(pdf, blockquote_text)
        when SECTION_DIVIDER, HORIZ_RULE_PATTERN, FOOTER_SEPARATOR
          format_section_divider(pdf, SPACE_SINGLE, SPACE_SINGLE)
        else
          format_paragraph_content(pdf, line)
        end

        i += 1
      end
    end

    def add_footer(pdf)
      footer_y_position = 0

      # Start a new page if we're too close to the bottom
      pdf.start_new_page if pdf.cursor < 80 # Need at least 80 points for footer

      pdf.bounding_box([0, footer_y_position + 30], width: pdf.bounds.width, height: 30) do
        pdf.font 'Helvetica', size: 8
        pdf.text "Generated: #{Time.current.strftime('%B %d, %Y at %I:%M %p %Z')}", align: :center
        pdf.move_down 2
        pdf.text "Document ID: #{generate_document_id}", align: :center
      end
    end

    def generate_document_id
      "DR-EMAIL-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
    end
  end
end
