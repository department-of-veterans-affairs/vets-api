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

        @pdf_data
      end

      private

      def section_0_claim_attributes
        claim_process_type = @auto_claim['standardClaim'] ? 'STANDARD_CLAIM_PROCESS' : 'FDC_PROGRAM'
        claim_process_type = 'BDD_PROGRAM' if any_service_end_dates_in_future_window?

        @pdf_data[:data][:attributes][:claimProcessType] = claim_process_type
      end

      def any_service_end_dates_in_future_window?
        @auto_claim['serviceInformation']['servicePeriods'].each do |sp|
          end_date = sp['activeDutyEndDate'].to_date
          return true if end_date >= 90.days.from_now && end_date <= 180.days.from_now
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
        @pdf_data[:data][:attributes][:identificationInformation] = {}
      end

      def set_pdf_data_for_mailing_address
        @pdf_data[:data][:attributes][:identificationInformation][:mailingAddress] = {}
      end

      def set_veteran_name
        @pdf_data[:data][:attributes][:identificationInformation][:name] = {}
      end
    end
  end
end
