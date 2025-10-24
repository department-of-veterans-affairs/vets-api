# frozen_string_literal: true

require 'prawn'
require 'common/file_helpers'

module DecisionReviews
  # Stamps personalized data onto static PDF email templates
  # Uses pdftk (via PdfForms) to overlay stamps onto existing PDFs
  class PdfTemplateStamper
    PDFTK = PdfForms.new(Settings.binaries.pdftk)

    # Coordinate mappings for where to stamp personalized data on each template
    # These would need to be calibrated based on actual template layouts
    # page: which page of the template PDF to stamp on (1-indexed)
    # fill_color: hex color for the covering box (optional, defaults to FFFFFF/white)
    FIELD_COORDINATES = {
      'hlr_form_failure' => {
        first_name: { x: 75, y: 439, size: 12, cover_width: 200, page: 1 },
        original_submission_timestamp: { x: 150, y: 609, size: 10, cover_width: 200, page: 1 },
        email_sent_timestamp: { x: 150, y: 666, size: 9.5, cover_width: 200, page: 1 },
        email_address: { x: 150, y: 652, size: 9.5, cover_width: 250, page: 1 },
        form_submission_date_details: { x: 80, y: 411, size: 12, cover_width: 200, page: 2, fill_color: 'F0F0F0' }
      },
      'sc_form_failure' => {
        first_name: { x: 75, y: 439, size: 12, cover_width: 200, page: 1 },
        original_submission_timestamp: { x: 150, y: 609, size: 10, cover_width: 200, page: 1 },
        email_sent_timestamp: { x: 150, y: 666, size: 9.5, cover_width: 200, page: 1 },
        email_address: { x: 150, y: 652, size: 9.5, cover_width: 250, page: 1 },
        form_submission_date_details: { x: 80, y: 411, size: 12, cover_width: 200, page: 2, fill_color: 'F0F0F0' }
      },
      'nod_form_failure' => {
        first_name: { x: 75, y: 439, size: 12, cover_width: 200, page: 1 },
        original_submission_timestamp: { x: 150, y: 609, size: 10, cover_width: 200, page: 1 },
        email_sent_timestamp: { x: 150, y: 666, size: 9.5, cover_width: 200, page: 1 },
        email_address: { x: 150, y: 652, size: 9.5, cover_width: 250, page: 1 },
        form_submission_date_details: { x: 80, y: 358, size: 12, cover_width: 200, page: 2, fill_color: 'F0F0F0' }
      },
      'sc_4142_failure' => {
        first_name: { x: 75, y: 425, size: 12, cover_width: 200, page: 1 },
        original_submission_timestamp: { x: 150, y: 608, size: 10, cover_width: 200, page: 1 },
        email_sent_timestamp: { x: 150, y: 666, size: 9.5, cover_width: 200, page: 1 },
        email_address: { x: 150, y: 652, size: 9.5, cover_width: 250, page: 1 },
        form_submission_date_body: { x: 43, y: 372, size: 11, cover_width: 100, page: 1 },
        form_submission_date_details: { x: 80, y: 400, size: 12, cover_width: 200, page: 2, fill_color: 'F0F0F0' }
      },
      'sc_evidence_failure' => {
        first_name: { x: 75, y: 438, size: 12, cover_width: 200, page: 1 },
        original_submission_timestamp: { x: 150, y: 608, size: 10, cover_width: 200, page: 1 },
        email_sent_timestamp: { x: 150, y: 666, size: 9.5, cover_width: 200, page: 1 },
        email_address: { x: 150, y: 652, size: 9.5, cover_width: 250, page: 1 },
        form_submission_date_body: { x: 367, y: 406, size: 12, cover_width: 130, page: 1 },
        evidence_filename: { x: 80, y: 282, size: 11, cover_width: 200, page: 1, fill_color: 'F0F0F0' }
      },
      'nod_evidence_failure' => {
        first_name: { x: 75, y: 397, size: 12, cover_width: 200, page: 1 },
        original_submission_timestamp: { x: 150, y: 608, size: 10, cover_width: 200, page: 1 },
        email_sent_timestamp: { x: 150, y: 666, size: 9.5, cover_width: 200, page: 1 },
        email_address: { x: 150, y: 652, size: 9.5, cover_width: 250, page: 1 },
        form_submission_date_body: { x: 43, y: 343, size: 11, cover_width: 100, page: 1 },
        evidence_filename: { x: 80, y: 238, size: 11, cover_width: 200, page: 1, fill_color: 'F0F0F0' }
      }
    }.freeze

    def initialize(template_type:)
      @template_type = template_type
      @template_path = template_file_path
    end

    def stamp_personalized_data(first_name:, submission_date:, email_address:, sent_date:, evidence_filename: nil,
                                **_unused)
      coordinates = FIELD_COORDINATES[@template_type]

      # Create stamp overlay PDF
      stamp_path = create_stamp_overlay(
        first_name:,
        submission_date:,
        email_address:,
        sent_date:,
        evidence_filename:,
        coordinates:
      )

      # Use pdftk multistamp to overlay the stamp onto the template
      # multistamp applies page N of stamp to page N of template (not all pages)
      output_path = "#{Common::FileHelpers.random_file_path}.pdf"

      begin
        PDFTK.multistamp(@template_path.to_s, stamp_path, output_path)

        # Read the stamped PDF
        pdf_binary = File.binread(output_path)
        pdf_binary
      ensure
        # Clean up temporary files
        Common::FileHelpers.delete_file_if_exists(stamp_path)
        Common::FileHelpers.delete_file_if_exists(output_path)
      end
    end

    private

    def template_file_path
      Rails.root.join('modules', 'decision_reviews', 'lib', 'decision_reviews', 'email_templates',
                      "#{@template_type}.pdf")
    end

    def format_timestamp(date)
      date.strftime('%a, %b %d, %Y at %l:%M %p %Z')
    end

    def format_simple_date(date)
      date.strftime('%B %d, %Y')
    end

    # Create a stamp overlay PDF with white boxes and text
    # Only stamps on pages specified in the field coordinates
    # All email templates are 2 pages, so we create a 2-page stamp PDF
    def create_stamp_overlay(first_name:, submission_date:, email_address:, sent_date:, evidence_filename:,
                             coordinates:)
      stamp_path = "#{Common::FileHelpers.random_file_path}.pdf"

      # Prepare field values
      field_values = {
        first_name: "#{first_name},",
        original_submission_timestamp: format_timestamp(submission_date),
        email_sent_timestamp: format_timestamp(sent_date),
        email_address:,
        form_submission_date_body: format_simple_date(submission_date),
        form_submission_date_details: format_simple_date(submission_date),
        evidence_filename:
      }

      Prawn::Document.generate(stamp_path, page_size: 'LETTER') do |pdf|
        # Create 2 pages (all email templates are 2 pages)
        # Using multistamp, page N of stamp goes to page N of template
        [1, 2].each do |page_num|
          # Add a new page for page 2
          pdf.start_new_page if page_num == 2

          # Stamp each field that belongs on this page
          coordinates.each do |field_name, coords|
            next unless coords[:page] == page_num
            next if field_name == :evidence_filename && evidence_filename.nil?

            cover_and_stamp(pdf, field_values[field_name], coords)
          end
          # Pages without fields remain blank (transparent when stamped)
        end
      end

      stamp_path
    end

    # Covers a placeholder with a colored box and stamps the real text on top
    # fill_color can be customized per field, defaults to white (FFFFFF)
    def cover_and_stamp(pdf, text, coords)
      x = coords[:x]
      y = coords[:y]
      size = coords[:size]
      cover_width = coords[:cover_width]
      fill_color = coords[:fill_color] || 'FFFFFF' # Default to white
      padding = 3

      # Draw box to cover placeholder (color customizable per field)
      pdf.fill_color fill_color
      # pdf.stroke_color 'FF0000' # Red outline for easier dev (can be removed later)
      # pdf.fill_rectangle [x, y], cover_width + (padding * 2), size + (padding * 2)
      pdf.fill_rectangle [x, y], cover_width + (padding * 2), size + 5
      # pdf.fill_rectangle [x, y], cover_width + (padding * 2), size + (padding * 2)

      # Stamp the real text
      pdf.fill_color '000000'
      pdf.draw_text text, at: [x + padding, y - padding - size], size:
    end
  end
end
