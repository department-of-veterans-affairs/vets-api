# frozen_string_literal: true

require 'common/file_helpers'
require 'hexapdf'

module DecisionReviews
  # Fills form fields in PDF email templates with personalized data
  # Sets fields to read-only to preserve accessibility while preventing edits
  class PdfTemplateStamper
    # Mapping of PDF form field names to our data field names
    # These field names must match exactly what's in the PDF (case-sensitive)
    FORM_FIELD_MAPPINGS = {
      'Recipient name' => :recipient_name,
      'Original submission attempt timestamp' => :original_submission_timestamp,
      'Email delivered timestamp' => :email_delivered_timestamp,
      'Recipient email address' => :recipient_email_address,
      'Original submission attempt date' => :original_submission_date,
      'Email delivery status' => :email_delivery_failure,
      'Evidence filename' => :evidence_filename
    }.freeze

    def initialize(template_type:)
      @template_type = template_type
      @template_path = template_file_path
    end

    # Stamp personalized data onto the PDF template
    # @param data [Hash] Personalization data with keys:
    #   - first_name [String] Recipient's first name
    #   - submission_date [Time] Original submission timestamp
    #   - email_address [String] Recipient's email
    #   - sent_date [Time] Email sent timestamp
    #   - email_delivery_failure [Boolean] Whether email delivery failed (default: false)
    #   - evidence_filename [String] Evidence filename for evidence failure templates (optional)
    # @return [String] Binary PDF content
    def stamp_personalized_data(data)
      form_data = build_form_data(data)
      output_path = "#{Common::FileHelpers.random_file_path}.pdf"

      begin
        fill_and_write_pdf(form_data, output_path, data[:email_delivery_failure])
        File.binread(output_path)
      ensure
        Common::FileHelpers.delete_file_if_exists(output_path)
      end
    end

    private

    def build_form_data(data)
      form_data = {
        'Recipient name' => "#{data[:first_name]},",
        'Original submission attempt timestamp' => format_timestamp(data[:submission_date]),
        'Email delivered timestamp' => format_timestamp(data[:sent_date]),
        'Recipient email address' => data[:email_address],
        'Original submission attempt date' => format_original_submission_attempt_date(data[:submission_date]),
        'Email delivery status' => data[:email_delivery_failure] ? '✗ Failure' : '✓ Success'
      }

      # Add evidence filename if provided (only for evidence failure templates)
      form_data['Evidence filename'] = data[:evidence_filename] if data[:evidence_filename]

      form_data
    end

    def fill_and_write_pdf(form_data, output_path, email_delivery_failure)
      if Flipper.enabled?(:acroform_debug_logs)
        Rails.logger.info("DecisionReviews::PdfTemplateStamper HexaPDF template: #{@template_path}")
      end

      doc = HexaPDF::Document.open(@template_path)

      fill_form_fields(doc, form_data, email_delivery_failure)
      configure_pdf_form(doc)
      doc.write(output_path, validate: true)
    end

    def fill_form_fields(doc, form_data, email_delivery_failure)
      form_data.each do |field_name, value|
        field = doc.acro_form&.field_by_name(field_name)
        next unless field

        apply_field_styling(field, field_name, email_delivery_failure)
        field.field_value = value
        make_field_readonly(field)
      end
    end

    def apply_field_styling(field, field_name, email_delivery_failure)
      return unless field_name == 'Email delivery status'

      # Red for failure (RGB: 0.8, 0, 0), Green for success (RGB: 0, 0.5, 0)
      color = email_delivery_failure ? [0.8, 0, 0] : [0, 0.5, 0]

      # Set the text color in the field's default appearance string
      # Format: /FontName FontSize Tf R G B rg
      field[:DA] = "/Helv 12 Tf #{color[0]} #{color[1]} #{color[2]} rg"
    end

    def make_field_readonly(field)
      # Set ReadOnly flag (bit 1) to prevent editing while preserving accessibility
      field[:Ff] = (field[:Ff] || 0) | 0x1
    end

    def configure_pdf_form(doc)
      return unless doc.acro_form

      # Enable NeedAppearances so PDF readers use our generated appearances
      doc.acro_form[:NeedAppearances] = true
    end

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

    def format_original_submission_attempt_date(date)
      formatted_date = format_simple_date(date)
      templates_with_comma = %w[nod_evidence_failure sc_evidence_failure sc_4142_failure]
      templates_with_comma.include?(@template_type) ? "#{formatted_date}," : formatted_date
    end
  end
end
