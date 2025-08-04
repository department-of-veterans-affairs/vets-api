# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'dependents_verification/pdf_fill/sections/section0'
require 'dependents_verification/pdf_fill/sections/section1'
require 'dependents_verification/pdf_fill/sections/section2'
require 'dependents_verification/pdf_fill/sections/section5'

module DependentsVerification
  module PdfFill
    # The Va21p0969 Form
    class Va210538 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper

      # The Form ID
      FORM_ID = DependentsVerification::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = DependentsVerification::PDF_PATH

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [Section0, Section1, Section2, Section5].freeze

      key = {}

      SECTION_CLASSES.each { |section| key.merge!(section::KEY) }

      # Form configuration hash
      KEY = key.freeze

      # Post-process form data to match the expected format.
      # Each section of the form is processed in its own expand function.
      #
      # @param _options [Hash] any options needed for post-processing
      #
      # @return [Hash] the processed form data
      #
      def merge_fields(options = {})
        created_at = options[:created_at] if options[:created_at].present?
        form_data['dateStamp'] = created_at || Time.zone.now
        expand_signature(form_data['veteranInformation']['fullName'],
                         created_at&.to_date || Time.zone.today)
        SECTION_CLASSES.each { |section| section.new.expand(form_data) }

        remove_fields(form_data)
      end

      private

      # Remove fields that are not needed in the final PDF
      def remove_fields(form_data)
        updated_form_data = form_data.deep_dup
        keys_to_remove = %w[
          veteranInformation
          address
          dependents
          email
          phone
          statementOfTruthSignature
          statementOfTruthCertified
          internationalPhone
          electronicCorrespondence
        ]
        keys_to_remove.each { |key| updated_form_data.delete(key) }

        updated_form_data
      end
    end
  end
end
