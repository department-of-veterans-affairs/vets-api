# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/forms/field_mappings/va214192'

module PdfFill
  module Forms
    class Va214192 < FormBase
      include FormHelper

      KEY = FieldMappings::Va214192::KEY

      # Coordinates for the 21-4192 employer signature field
      SIGNATURE_X = 60
      SIGNATURE_Y = 230
      SIGNATURE_PAGE = 1 # zero-indexed; 1 == page 2
      SIGNATURE_SIZE = 10

      def merge_fields(options = {})
        merge_veteran_info
        merge_employment_info
        merge_military_duty
        merge_benefits
        merge_certification(options)
        @form_data
      end

      # Stamp a typed signature string onto the PDF using DatestampPdf
      #
      # @param pdf_path [String] Path to the PDF to stamp
      # @param form_data [Hash] The form data containing the signature
      # @return [String] Path to the stamped PDF (or the original path if signature is blank/on failure)
      def self.stamp_signature(pdf_path, form_data)
        signature_text = form_data.dig('certification', 'signature')

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
        Rails.logger.error('Form214192: Error stamping signature', error: e.message, backtrace: e.backtrace)
        pdf_path # Return original PDF if stamping fails
      end

      private

      def merge_veteran_info
        return unless @form_data['veteranInformation']

        vet_info = @form_data['veteranInformation']
        merge_ssn_fields(vet_info)
        merge_date_of_birth(vet_info)
      end

      def merge_ssn_fields(vet_info)
        return unless vet_info['ssn']

        ssn = vet_info['ssn'].to_s.gsub(/\D/, '')
        ssn_parts = {
          'first' => ssn[0..2],
          'second' => ssn[3..4],
          'third' => ssn[5..8]
        }
        # Populate SSN on both page 1 and page 2
        @form_data['veteranInformation']['ssn'] = ssn_parts
        @form_data['veteranInformation']['ssnPage2'] = ssn_parts
      end

      def merge_date_of_birth(vet_info)
        return unless vet_info['dateOfBirth']

        dob = parse_date(vet_info['dateOfBirth'])
        return unless dob

        @form_data['veteranInformation']['dateOfBirth'] = {
          'month' => dob[:month],
          'day' => dob[:day],
          'year' => dob[:year]
        }
      end

      def merge_employment_info
        return unless @form_data['employmentInformation']

        emp_info = @form_data['employmentInformation']
        merge_employer_address(emp_info)
        merge_employment_dates(emp_info)
        merge_amount_earned(emp_info)
        merge_radio_buttons(emp_info)
      end

      def merge_employer_address(emp_info)
        return unless emp_info['employerName'] || emp_info['employerAddress']

        name_and_addr = []
        name_and_addr << emp_info['employerName'] if emp_info['employerName']
        if emp_info['employerAddress']
          addr = emp_info['employerAddress']
          name_and_addr << addr['street'] if addr['street']
          name_and_addr << addr['street2'] if addr['street2']
          name_and_addr << "#{addr['city']}, #{addr['state']} #{addr['postalCode']}" if addr['city']
        end
        @form_data['employmentInformation']['employerNameAndAddress'] = name_and_addr.join("\n")
      end

      def merge_employment_dates(emp_info)
        %w[beginningDateOfEmployment endingDateOfEmployment dateLastWorked lastPaymentDate
           datePaid].each do |date_field|
          next unless emp_info[date_field]

          parsed = parse_date(emp_info[date_field])
          next unless parsed

          @form_data['employmentInformation'][date_field] = {
            'month' => parsed[:month],
            'day' => parsed[:day],
            'year' => parsed[:year]
          }
        end
      end

      def merge_amount_earned(emp_info)
        return unless emp_info['amountEarnedLast12MonthsOfEmployment']

        amount = emp_info['amountEarnedLast12MonthsOfEmployment'].to_f
        dollars = amount.floor
        cents = ((amount - dollars) * 100).round

        thousands = (dollars / 1000).floor
        hundreds = dollars % 1000

        amount_parts = {
          'thousands' => thousands.to_s.rjust(3, '0'),
          'hundreds' => hundreds.to_s.rjust(3, '0'),
          'cents' => cents.to_s.rjust(2, '0')
        }
        @form_data['employmentInformation']['amountEarnedLast12MonthsOfEmployment'] = amount_parts
      end

      def merge_radio_buttons(emp_info)
        return unless emp_info.key?('lumpSumPaymentMade')

        @form_data['employmentInformation']['lumpSumPaymentMade'] = emp_info['lumpSumPaymentMade'] ? 'YES' : 'NO'
      end

      def merge_military_duty
        return unless @form_data['militaryDutyStatus']

        # Convert boolean to YES/NO for radio button
        if @form_data['militaryDutyStatus'].key?('veteranDisabilitiesPreventMilitaryDuties')
          prevents = @form_data['militaryDutyStatus']['veteranDisabilitiesPreventMilitaryDuties']
          @form_data['militaryDutyStatus']['veteranDisabilitiesPreventMilitaryDuties'] = prevents ? 'YES' : 'NO'
        end
      end

      def merge_benefits
        return unless @form_data['benefitEntitlementPayments']

        benefits = @form_data['benefitEntitlementPayments']
        merge_benefit_radio_buttons(benefits)
        merge_benefit_amount(benefits)
        merge_benefit_dates(benefits)
      end

      def merge_benefit_radio_buttons(benefits)
        return unless benefits.key?('sickRetirementOtherBenefits')

        @form_data['benefitEntitlementPayments']['sickRetirementOtherBenefits'] =
          benefits['sickRetirementOtherBenefits'] ? 'YES' : 'NO'
      end

      def merge_benefit_amount(benefits)
        return unless benefits['grossMonthlyAmountOfBenefit']

        amount = benefits['grossMonthlyAmountOfBenefit'].to_f
        dollars = amount.floor
        cents = ((amount - dollars) * 100).round

        thousands = (dollars / 1000).floor
        hundreds = dollars % 1000

        @form_data['benefitEntitlementPayments']['grossMonthlyAmountOfBenefit'] = {
          'thousands' => thousands.to_s.rjust(3, '0'),
          'hundreds' => hundreds.to_s.rjust(3, '0'),
          'cents' => cents.to_s.rjust(2, '0')
        }
      end

      def merge_benefit_dates(benefits)
        %w[dateBenefitBegan dateFirstPaymentIssued dateBenefitWillStop].each do |date_field|
          next unless benefits[date_field]

          parsed = parse_date(benefits[date_field])
          next unless parsed

          @form_data['benefitEntitlementPayments'][date_field] = {
            'month' => parsed[:month],
            'day' => parsed[:day],
            'year' => parsed[:year]
          }
        end
      end

      def merge_certification(options = {})
        return unless @form_data['certification']

        # Auto-generate certification date (MM/DD/YYYY format)
        certification_date = options[:created_at]&.to_date || Time.zone.today
        date = {
          month: certification_date.month.to_s.rjust(2, '0'),
          day: certification_date.day.to_s.rjust(2, '0'),
          year: certification_date.year.to_s
        }

        @form_data['certification']['certificationDate'] = "#{date[:month]}/#{date[:day]}/#{date[:year]}"

        # Signature should already be set from form data, just ensure it's present
        # The signature field will be passed through as-is to the PDF
      end

      def parse_date(date_string)
        return nil unless date_string

        date = Date.parse(date_string.to_s)
        {
          month: date.month.to_s.rjust(2, '0'),
          day: date.day.to_s.rjust(2, '0'),
          year: date.year.to_s
        }
      rescue ArgumentError
        nil
      end
    end
  end
end
