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

        def base_profile
          {
            FirstName: inquiry_params.dig(:about_yourself, :first),
            MiddleName: inquiry_params.dig(:about_yourself, :middle),
            LastName: inquiry_params.dig(:about_yourself, :last),
            PreferredName: inquiry_params[:preferred_name],
            Suffix: @translator.call(inquiry_params.dig(:about_yourself, :suffix)),
            Gender: nil,
            Pronouns: formatted_pronouns(inquiry_params[:pronouns]),
            Country: country_data,
            Street: inquiry_params.dig(:address, :street),
            City: inquiry_params.dig(:address, :city),
            State: state_data,
            ZipCode: inquiry_params[:postal_code],
            Province: inquiry_params[:province],
            DateOfBirth: inquiry_params.dig(:about_yourself, :date_of_birth)
          }
        end

        def contact_info
          @contact_info ||= {
            BusinessPhone: contact_field(:phone_number, 'Business'),
            PersonalPhone: contact_field(:phone_number, 'Personal'),
            BusinessEmail: contact_field(:email_address, 'Business'),
            PersonalEmail: contact_field(:email_address, 'Personal')
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
            BranchOfService: inquiry_params.dig(:about_yourself, :branch_of_service),
            SSN: inquiry_params.dig(:about_yourself, :ssn),
            EDIPI: user&.edipi,
            ICN: user&.icn,
            ServiceNumber: nil,
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
            Name: fetch_state(inquiry_params.dig(:address, :state)),
            StateCode: inquiry_params.dig(:address, :state)
          }
        end

        def contact_field(field, type)
          inquiry_details[:level_of_authentication] == type ? inquiry_params[field] : nil
        end
      end
    end
  end
end
