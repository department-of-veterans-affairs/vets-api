# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      class SubmitterProfile
        include SharedHelpers

        class SubmitterProfileError < StandardError; end

        attr_reader :inquiry_params, :user, :inquiry_details

        def initialize(inquiry_params:, user:, inquiry_details:)
          @inquiry_params = inquiry_params
          @user = user
          @inquiry_details = inquiry_details
          @translator = Translator.new
        end

        def call
          base_profile
            .merge(contact_info)
            .merge(school_info)
            .merge(service_info)
        end

        private

        def submitter_info
          @submitter_info ||= inquiry_params[:about_yourself] || {}
        end

        def submitter_address
          @submitter_address ||= inquiry_params[:address] || {}
        end

        def base_profile
          {
            FirstName: submitter_info[:first],
            MiddleName: submitter_info[:middle],
            LastName: submitter_info[:last],
            PreferredName: inquiry_params[:preferred_name],
            Suffix: @translator.call(:suffix, submitter_info[:suffix]),
            Gender: nil,
            Pronouns: formatted_pronouns(inquiry_params[:pronouns]) || inquiry_params[:pronouns_not_listed_text],
            Country: country_data,
            Street: submitter_address[:street],
            City: submitter_address[:city],
            State: state_data,
            ZipCode: inquiry_params[:postal_code],
            Province: inquiry_params[:province],
            DateOfBirth: submitter_info[:date_of_birth]
          }
        end

        def contact_info
          @contact_info ||= {
            BusinessPhone: retrieve_contact_field(:phone_number, 'Business'),
            PersonalPhone: retrieve_contact_field(:phone_number, 'Personal'),
            BusinessEmail: retrieve_contact_field(:email_address, 'Business'),
            PersonalEmail: retrieve_contact_field(:email_address, 'Personal')
          }
        end

        def school_info
          {
            SchoolState: inquiry_params.dig(:school_obj, :state_abbreviation),
            SchoolFacilityCode: inquiry_params.dig(:school_obj, :school_facility_code),
            SchoolId: nil
          }
        end

        def service_info
          {
            BranchOfService: submitter_info[:branch_of_service],
            SSN: submitter_info.dig(:social_or_service_num, :ssn),
            EDIPI: user&.edipi,
            ICN: user&.icn,
            ServiceNumber: submitter_info.dig(:social_or_service_num, :service_number),
            ClaimNumber: nil,
            VeteranServiceStateDate: nil,
            VeteranServiceEndDate: nil
          }
        end

        def country_data
          {
            Name: fetch_country(inquiry_params[:country]),
            CountryCode: inquiry_params[:country]
          }
        end

        def state_data
          {
            Name: fetch_state(submitter_address[:state]),
            StateCode: submitter_address[:state]
          }
        end

        def retrieve_contact_field(field, required_authentication_level)
          inquiry_details[:level_of_authentication] == required_authentication_level ? inquiry_params[field] : nil
        end
      end
    end
  end
end
