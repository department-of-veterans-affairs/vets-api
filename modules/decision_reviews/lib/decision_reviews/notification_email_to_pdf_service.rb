# frozen_string_literal: true

require 'prawn/table'

module DecisionReviews
  class NotificationEmailToPdfService
    def initialize(email_content:, email_subject:, email_address:, sent_date:, submission_date:, first_name:, evidence_filename: nil)
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

    private

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

      if @evidence_filename
        content += "Evidence Filename: #{@evidence_filename}\n"
      end

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

      # 2. If evidence filename exists, replace <redacted> after "Here's the file name of the document we need"
      if @evidence_filename
        content = content.gsub(/Here's the file name of the document we need[:\s]*<redacted>/i,
                              "Here's the file name of the document we need: #{@evidence_filename}")
      end

      # 3. Replace any remaining <redacted> fields with formatted submission date
      formatted_submission_date = @submission_date.strftime('%B %d, %Y')
      content = content.gsub('<redacted>', formatted_submission_date)

      content
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

        add_header(pdf)

        add_formatted_content(pdf, content)

        add_footer(pdf)
      end.render
    end

    def add_header(pdf)
      # VA logo area (placeholder for now)
      pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: 60) do
        pdf.font 'Helvetica-Bold', size: 16
        pdf.text 'Department of Veterans Affairs', align: :center
        pdf.move_down 5
        pdf.font 'Helvetica', size: 12
        pdf.text 'Decision Reviews Notification Email Archive', align: :center
        pdf.stroke_horizontal_rule
      end
      pdf.move_down 20
    end

    def add_formatted_content(pdf, content)
      lines = content.split("\n")

      lines.each do |line|
        case line
        when /^={3,}/ # Header underlines
          next # Skip underline characters, we'll format headers differently
        when /^-{3,}/ # Section dividers
          pdf.move_down 10
          pdf.stroke_horizontal_rule
          pdf.move_down 10
        when /^Decision Reviews Notification Email$/
          pdf.font 'Helvetica-Bold', size: 18
          pdf.text line, align: :center
          pdf.move_down 15
        when /^Email Metadata:$/, /^Email Content:$/
          pdf.move_down 10
          pdf.font 'Helvetica-Bold', size: 14
          pdf.text line
          pdf.move_down 8
        when /^(To|Subject|Email Sent Date|Original Submission Date|Evidence Filename):/
          # Format metadata as key-value pairs
          key, value = line.split(':', 2)
          pdf.font 'Helvetica-Bold', size: 11
          pdf.text key + ':', inline_format: true
          pdf.font 'Helvetica', size: 11
          pdf.text value.strip if value
          pdf.move_down 5
        when /^---$/
          # Footer separator
          pdf.move_down 15
          pdf.stroke_horizontal_rule
          pdf.move_down 10
        else
          # Regular content
          unless line.strip.empty?
            pdf.font 'Helvetica', size: 11
            pdf.text line.strip
            pdf.move_down 5
          else
            pdf.move_down 8
          end
        end
      end
    end

    def add_footer(pdf)
      pdf.bounding_box([0, 50], width: pdf.bounds.width, height: 40) do
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
