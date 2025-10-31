# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/forms/field_mappings/va214192'

module PdfFill
  module Forms
    class Va214192 < FormBase
      include FormHelper

      KEY = FieldMappings::Va214192::KEY

      def merge_fields(_options = {})
        merge_veteran_info
        merge_employment_info
        merge_military_duty
        merge_benefits
        merge_certification
        @form_data
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

      def merge_certification
        return unless @form_data['employerCertification']

        cert = @form_data['employerCertification']

        # Format certification date (expecting MM/DD/YYYY format)
        if cert['certificationDate']
          date = parse_date(cert['certificationDate'])
          if date
            @form_data['employerCertification']['certificationDate'] = "#{date[:month]}/#{date[:day]}/#{date[:year]}"
          end
        end
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
