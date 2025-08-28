# frozen_string_literal: true

module PdfFilenameGenerator
  extend ActiveSupport::Concern

  private

  # Generates a PDF filename based on form data and prefix.
  #
  # Creates a filename using the form prefix and veteran's name from the parsed form data.
  # If name fields are missing or empty, they are omitted from the filename gracefully.
  #
  # @param parsed_form [Hash] The parsed form data containing veteran information
  # @param field [String] The field name containing name data (e.g., 'veteranFullName', 'fullName')
  # @param form_prefix [String] The form identifier to prefix the filename (e.g., '10-10EZ', '10-10EZR')
  #
  # @return [String] The generated PDF filename with .pdf extension
  def file_name_for_pdf(parsed_form, field, form_prefix)
    first_name = parsed_form.dig(field, 'first').presence
    last_name = parsed_form.dig(field, 'last').presence

    "#{[form_prefix, first_name, last_name].compact.join('_')}.pdf"
  end
end
