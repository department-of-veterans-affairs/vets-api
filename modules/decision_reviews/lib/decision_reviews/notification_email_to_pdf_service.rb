# frozen_string_literal: true

require 'prawn/table'

module DecisionReviews
  # Service to convert notification email content to PDF format
  # Handles all 6 template types: HLR/NOD/SC form errors, NOD/SC evidence errors, and SC secondary form errors
  class NotificationEmailToPdfService
    # Template type constants matching the email job patterns
    TEMPLATE_TYPES = {
      form: {
        'HLR' => 'higher_level_review_form_error',
        'NOD' => 'notice_of_disagreement_form_error',
        'SC' => 'supplemental_claim_form_error'
      },
      evidence: {
        'NOD' => 'notice_of_disagreement_evidence_error',
        'SC' => 'supplemental_claim_evidence_error'
      },
      secondary_form: {
        'SC' => 'supplemental_claim_secondary_form_error'
      }
    }.freeze

    def initialize(email_content:, email_subject:, email_address:, sent_date:, submission_date:, template_type:, appeal_type: nil)
      @email_content = email_content
      @email_subject = email_subject
      @email_address = email_address
      @sent_date = sent_date
      @submission_date = submission_date
      @template_type = template_type.to_sym
      @appeal_type = appeal_type

      validate_template_type!
    end

    # Generate PDF from email content and save to temporary file
    # Returns the file path to the generated PDF
    def generate_pdf
      pdf_content = build_pdf_content
      generate_pdf_file(pdf_content)
    end

    # Get the full template identifier for this email
    def template_identifier
      case @template_type
      when :form, :evidence
        TEMPLATE_TYPES[@template_type][@appeal_type]
      when :secondary_form
        TEMPLATE_TYPES[@template_type]['SC']
      end
    end

    private

    def validate_template_type!
      unless TEMPLATE_TYPES.key?(@template_type)
        raise ArgumentError, "Invalid template_type: #{@template_type}. Must be one of: #{TEMPLATE_TYPES.keys.join(', ')}"
      end

      case @template_type
      when :form, :evidence
        unless @appeal_type && TEMPLATE_TYPES[@template_type].key?(@appeal_type)
          valid_types = TEMPLATE_TYPES[@template_type].keys.join(', ')
          raise ArgumentError, "Invalid appeal_type for #{@template_type}: #{@appeal_type}. Must be one of: #{valid_types}"
        end
      when :secondary_form
        # Secondary form is only for SC type, no additional validation needed
      end
    end

    def build_pdf_content
      <<~CONTENT
        Decision Reviews Notification Email
        ==================================

        Email Metadata:
        ---------------
        To: #{@email_address}
        Subject: #{@email_subject}
        Template Type: #{template_identifier}
        Sent Date: #{@sent_date.strftime('%B %d, %Y at %I:%M %p %Z')}
        Original Submission Date: #{@submission_date.strftime('%B %d, %Y at %I:%M %p %Z')}

        Email Content:
        --------------
        #{@email_content}

        ---
        This PDF was generated from a VA notification email sent via VA Notify service.
      CONTENT
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
        when /^(To|Subject|Template Type|Sent Date|Original Submission Date):/
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
      # Generate a unique document ID for tracking
      "DR-EMAIL-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
    end
  end
end
