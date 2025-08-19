# frozen_string_literal: true

module PdfFilenameGenerator
  extend ActiveSupport::Concern

  private

  def file_name_for_pdf(parsed_form, form_prefix)
    first_name = parsed_form.dig('veteranFullName', 'first').presence
    last_name = parsed_form.dig('veteranFullName', 'last').presence

    "#{[form_prefix, first_name, last_name].compact.join('_')}.pdf"
  end
end
