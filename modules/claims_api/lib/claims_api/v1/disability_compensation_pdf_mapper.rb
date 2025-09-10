# frozen_string_literal: true

require_relative '../pdf_mapper_base'

module ClaimsApi
  module V1
    class DisabilityCompensationPdfMapper
      include PdfMapperBase

      def initialize(auto_claim, pdf_data, auth_headers, middle_initial)
        @auto_claim = auto_claim
        @pdf_data = pdf_data
        @auth_headers = auth_headers&.deep_symbolize_keys
        @middle_initial = middle_initial
      end

      def map_claim
        section_0_claim_attributes
        section_1_veteran_identification
        section_2_change_of_address

        @pdf_data
      end

      private

      def section_0_claim_attributes
        claim_process_type = @auto_claim['standardClaim'] ? 'STANDARD_CLAIM_PROCESS' : 'FDC_PROGRAM'
        claim_process_type = 'BDD_PROGRAM' if any_service_end_dates_in_bdd_window?

        @pdf_data[:data][:attributes][:claimProcessType] = claim_process_type
      end

      def any_service_end_dates_in_bdd_window?
        @auto_claim['serviceInformation']['servicePeriods'].each do |sp|
          end_date = sp['activeDutyEndDate'].to_date
          if end_date >= 90.days.from_now.to_date && end_date <= 180.days.from_now.to_date
            set_pdf_data_for_section_one

            future_date = make_date_string_month_first(sp['activeDutyEndDate'], sp['activeDutyEndDate'].length)
            @pdf_data[:data][:attributes][:identificationInformation][:dateOfReleaseFromActiveDuty] = future_date
            return true
          end
        end

        false
      end

      def section_1_veteran_identification
        set_pdf_data_for_section_one

        mailing_address
        va_employee_status
        veteran_ssn
        veteran_file_number
        veteran_name
        veteran_birth_date

        @pdf_data
      end

      def mailing_address
        mailing_addr = @auto_claim&.dig('veteran', 'currentMailingAddress')
        return if mailing_addr.blank?

        set_pdf_data_for_mailing_address

        address_base = @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress]

        address_data = {
          numberAndStreet: concatenate_address(mailing_addr['addressLine1'], mailing_addr['addressLine2'],
                                               mailing_addr['addressLine3']),
          city: mailing_addr['city'],
          state: mailing_addr['state'],
          country: mailing_addr['country'],
          zip: concatenate_zip_code(mailing_addr)
        }.compact

        address_base.merge!(address_data)
      end

      def va_employee_status
        employee_status = @auto_claim&.dig('veteran', 'currentlyVAEmployee')
        return if employee_status.nil?

        @pdf_data[:data][:attributes][:identificationInformation][:currentVaEmployee] = employee_status
      end

      def veteran_ssn
        ssn = @auth_headers[:va_eauth_pnid]
        @pdf_data[:data][:attributes][:identificationInformation][:ssn] = format_ssn(ssn) if ssn.present?
      end

      def veteran_file_number
        file_number = @auth_headers[:va_eauth_birlsfilenumber]
        @pdf_data[:data][:attributes][:identificationInformation][:vaFileNumber] = file_number
      end

      def veteran_name
        set_veteran_name

        fname = @auth_headers[:va_eauth_firstName]
        lname = @auth_headers[:va_eauth_lastName]

        @pdf_data[:data][:attributes][:identificationInformation][:name][:firstName] = fname
        @pdf_data[:data][:attributes][:identificationInformation][:name][:lastName] = lname
        @pdf_data[:data][:attributes][:identificationInformation][:name][:middleInitial] = @middle_initial
      end

      def veteran_birth_date
        birth_date_data = @auth_headers[:va_eauth_birthdate]
        birth_date = format_birth_date(birth_date_data) if birth_date_data

        @pdf_data[:data][:attributes][:identificationInformation][:dateOfBirth] = birth_date
      end

      def set_pdf_data_for_section_one
        return if @pdf_data[:data][:attributes].key?(:identificationInformation)

        @pdf_data[:data][:attributes][:identificationInformation] = {}
      end

      def set_pdf_data_for_mailing_address
        return if @pdf_data[:data][:attributes][:identificationInformation].key?(:mailingAddress)

        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress] = {}
      end

      def set_veteran_name
        @pdf_data[:data][:attributes][:identificationInformation][:name] = {}
      end

      def section_2_change_of_address
        address_info = @auto_claim&.dig('veteran', 'changeOfAddress')
        return if address_info.blank?

        set_pdf_data_for_section_two

        change_of_address_dates(address_info)
        change_of_address_location(address_info)
        change_of_address_type(address_info)
      end

      def set_pdf_data_for_section_two
        @pdf_data[:data][:attributes][:changeOfAddress] = {}
      end

      def change_of_address_dates(address_info)
        set_pdf_data_for_change_of_address_dates

        start_date = address_info&.dig('beginningDate')
        end_date = address_info&.dig('endingDate')

        if start_date.present? # This is required but checking to be safe anyways
          @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:start] =
            make_date_object(start_date, start_date.length)
        end
        if end_date.present?
          @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates][:end] =
            make_date_object(end_date, end_date.length)
        end
      end

      def set_pdf_data_for_change_of_address_dates
        return if @pdf_data[:data][:attributes][:changeOfAddress]&.key?(:effectiveDates)

        @pdf_data[:data][:attributes][:changeOfAddress][:effectiveDates] = {}
      end

      def change_of_address_location(address_info)
        set_pdf_data_for_change_of_address_location

        number_and_street = concatenate_address(address_info['addressLine1'], address_info['addressLine2'])
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:numberAndStreet] = number_and_street

        city = address_info&.dig('city')
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:city] = city if city.present?

        state = address_info&.dig('state')
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:state] = state if state.present?

        zip = concatenate_zip_code(address_info)
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:zip] = zip if zip.present?

        # required
        country = address_info&.dig('country')
        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress][:country] = format_country(country)
      end

      def set_pdf_data_for_change_of_address_location
        return if @pdf_data[:data][:attributes][:changeOfAddress]&.key?(:newAddress)

        @pdf_data[:data][:attributes][:changeOfAddress][:newAddress] = {}
      end

      def change_of_address_type(address_info)
        @pdf_data[:data][:attributes][:changeOfAddress][:typeOfAddressChange] = address_info&.dig('addressChangeType')
      end
    end
  end
end
