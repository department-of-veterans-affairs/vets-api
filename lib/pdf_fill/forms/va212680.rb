# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/field_mappings/va212680'

module PdfFill
  module Forms
    class Va212680 < FormBase
      include FormHelper
      include FormHelper::PhoneNumberFormatting
      KEY = FieldMappings::Va212680::KEY
      ITERATOR = PdfFill::HashConverter::ITERATOR

      # Coordinates for the 21-2680 veteran signature field
      # Located in Section V, field 15A on page 2
      SIGNATURE_X = 60
      SIGNATURE_Y = 535
      SIGNATURE_PAGE = 1 # zero-indexed; 1 == page 2
      SIGNATURE_SIZE = 10

      RELATIONSHIPS = { 'self' => 1,
                        'spouse' => 2,
                        'parent' => 2,
                        'child' => 4 }.freeze

      BENEFITS = { 'smc' => 1,
                   'smp' => 2 }.freeze

      def merge_fields(_options = {})
        transform_country_codes
        expand_veteran_ssn
        split_claimant_postal_code
        split_dates
        split_phone
        merge_hospital_address
        checkboxify
        relationship
        benefit
        hospitalized_checkbox
        split_email
        @form_data
      end

      # Stamp a typed signature string onto the PDF using DatestampPdf
      #
      # @param pdf_path [String] Path to the PDF to stamp
      # @param form_data [Hash] The form data containing the signature
      # @return [String] Path to the stamped PDF (or the original path if signature is blank/on failure)
      def self.stamp_signature(pdf_path, form_data)
        signature_text = form_data.dig('veteranSignature', 'signature')

        # Return original path if signature is blank
        return pdf_path if signature_text.nil? || signature_text.to_s.strip.empty?

        PDFUtilities::DatestampPdf.new(pdf_path).run(
          text: signature_text,
          x: SIGNATURE_X,
          y: SIGNATURE_Y,
          page_number: SIGNATURE_PAGE,
          size: SIGNATURE_SIZE,
          text_only: true,
          timestamp: '',
          template: pdf_path,
          multistamp: true
        )
      rescue => e
        Rails.logger.error('Form212680: Error stamping signature', error: e.message, backtrace: e.backtrace)
        pdf_path # Return original PDF if stamping fails
      end

      private

      def transform_country_codes
        # Transform claimant address country code from 3-char to 2-char
        claimant_address = @form_data.dig('claimantInformation', 'address')
        if claimant_address&.key?('country')
          transformed = extract_country(claimant_address)
          claimant_address['country'] = transformed if transformed
        end

        # Transform hospital address country code from 3-char to 2-char
        hospital_address = @form_data.dig('additionalInformation', 'hospitalAddress')
        if hospital_address&.key?('country')
          transformed = extract_country(hospital_address)
          hospital_address['country'] = transformed if transformed
        end
      end

      # TODO: review everything below here for nil checks
      def relationship
        @form_data['claimantInformation']['relationship'] =
          RELATIONSHIPS[ @form_data['claimantInformation']['relationship'] ] || 'Off'
      end

      def benefit
        @form_data['benefitInformation']['benefitSelection'] =
          BENEFITS[ @form_data['benefitInformation']['benefitSelection'] ] || 'Off'
      end

      def hospitalized_checkbox
        hospitalized_checkbox_value = @form_data.dig('additionalInformation', 'currentlyHospitalized')
        @form_data['additionalInformation']['currentlyHospitalized'] =
          case hospitalized_checkbox_value
          when nil
            'Off'
          when true
            '1'
          else
            '2'
          end
      end

      def checkboxify
        @form_data['claimantInformation']['agreeToElectronicCorrespondence'] =
          select_checkbox(@form_data.dig('claimantInformation', 'agreeToElectronicCorrespondence'))
      end

      def expand_veteran_ssn
        # veteran ssn is repeated at the top of pages
        veteran_ssn = split_ssn(@form_data['veteranInformation']['ssn'])
        @form_data['veteranInformation']['ssn'] = {}
        4.times do |i|
          @form_data['veteranInformation']["ssn#{i + 1}"] = veteran_ssn
        end

        @form_data['claimantInformation']['ssn'] = split_ssn(@form_data['claimantInformation']['ssn'])
      end

      def split_claimant_postal_code
        addr = @form_data.dig('claimantInformation', 'address')
        if addr&.dig('postalCode').present?
          @form_data['claimantInformation']['address']['postalCode'] =
            split_postal_code(addr)
        end
      end

      def split_dates
        @form_data['veteranInformation']['dateOfBirth'] = split_date(@form_data['veteranInformation']['dateOfBirth'])
        @form_data['additionalInformation']['admissionDate'] =
          split_date(@form_data['additionalInformation']['admissionDate'])
        @form_data['veteranSignature']['date'] =
          split_date(@form_data.dig('veteranSignature', 'date'))
        @form_data['claimantInformation']['dateOfBirth'] = split_date(@form_data['claimantInformation']['dateOfBirth'])
      end

      def split_phone
        phone = @form_data['claimantInformation']['phoneNumber']
        return if phone.blank?

        @form_data['claimantInformation']['phoneNumber'] = expand_phone_number(phone)
      end

      def merge_hospital_address
        @form_data['additionalInformation']['hospitalAddress'] =
          combine_full_address_extras(@form_data['additionalInformation']['hospitalAddress'])
      end

      def split_email
        email = @form_data['claimantInformation']['email']
        return if email.blank?

        @form_data['claimantInformation']['email'] = {
          'first' => email[0..34],
          'second' => email[35..] || ''
        }
      end

      def combine_full_address_extras(address)
        return if address.blank?

        [
          address['street'],
          address['street2'],
          [address['city'], address['state'], address['zipCode'], address['country']].compact.join(', ')
        ].compact.join("\n")
      end
    end
  end
end
