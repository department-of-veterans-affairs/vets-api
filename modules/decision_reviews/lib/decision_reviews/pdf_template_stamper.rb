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

    def stamp_personalized_data(first_name:, submission_date:, email_address:, sent_date:,
                                email_delivery_failure: false, evidence_filename: nil, **_unused)
      # Build the form field data hash with PDF field names as keys
      form_data = {
        'Recipient name' => "#{first_name},",
        'Original submission attempt timestamp' => format_timestamp(submission_date),
        'Email delivered timestamp' => format_timestamp(sent_date),
        'Recipient email address' => email_address,
        'Original submission attempt date' => format_original_submission_attempt_date(submission_date),
        'Email delivery status' => email_delivery_failure ? '✗ Failure' : '✓ Success'
      }

      # Add evidence filename if provided (only for evidence failure templates)
      form_data['Evidence filename'] = evidence_filename if evidence_filename

      output_path = "#{Common::FileHelpers.random_file_path}.pdf"

      begin
        doc = HexaPDF::Document.open(@template_path)

        # Fill each form field and set to read-only
        form_data.each do |field_name, value|
          field = doc.acro_form&.field_by_name(field_name)
          next unless field

          # Set color for Email Delivery field based on success/failure BEFORE setting value
          if field_name == 'Email delivery status'
            # Red for failure (RGB: 0.8, 0, 0), Green for success (RGB: 0, 0.5, 0)
            color = email_delivery_failure ? [0.8, 0, 0] : [0, 0.5, 0]

            # Set the text color in the field's default appearance string
            # Format: /FontName FontSize Tf R G B rg
            field[:DA] = "/Helv 12 Tf #{color[0]} #{color[1]} #{color[2]} rg"
          end

          # Set the field value (after DA is set)
          field.field_value = value

          # Set ReadOnly flag (bit 1) to prevent editing while preserving accessibility
          field[:Ff] = (field[:Ff] || 0) | 0x1
        end

        # Regenerate all form field appearances with the updated DA strings
        # doc.acro_form.create_appearances if doc.acro_form

        # Disable NeedAppearances so PDF readers use our generated appearances
        doc.acro_form[:NeedAppearances] = true if doc.acro_form

        # Write the filled PDF with read-only fields
        doc.write(output_path, validate: true)

        # Read and return the filled PDF
        File.binread(output_path)
      ensure
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

    def format_original_submission_attempt_date(date)
      formatted_date = format_simple_date(date)
      @template_type == 'nod_evidence_failure' ? "#{formatted_date}," : formatted_date
    end
  end
end
