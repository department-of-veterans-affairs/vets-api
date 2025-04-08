# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module PayloadBuilder
      class SubmitterProfile < ProfileBuilderBase
        def call
          base_profile
            .merge(contact_info)
            .merge(school_info)
            .merge(service_info(submitter_info))
        end

        private

        # Retrieves information about the submitter
        def submitter_info
          @submitter_info ||= inquiry_params.fetch(:about_yourself, {})
        end

        # Retrieves the address of the submitter
        def submitter_address
          @submitter_address ||= inquiry_params.fetch(:address, {})
        end

        # Builds the base profile payload
        def base_profile
          {
            FirstName: submitter_info[:first],
            MiddleName: submitter_info[:middle],
            LastName: submitter_info[:last],
            PreferredName: inquiry_params[:preferred_name],
            Suffix: @translator.call(:suffix, submitter_info[:suffix]),
            Pronouns: formatted_pronouns(inquiry_params[:pronouns]) || inquiry_params[:pronouns_not_listed_text],
            Country: country_data(inquiry_params[:country]),
            **address_data(submitter_address, inquiry_params[:your_postal_code]),
            DateOfBirth: submitter_info[:date_of_birth]
          }
        end

        def service_info(info)
          {
            BranchOfService: info[:branch_of_service],
            SSN: info.dig(:social_or_service_num, :ssn) || info[:social_num],
            EDIPI: user&.edipi,
            ICN: user&.icn,
            ServiceNumber: info.dig(:social_or_service_num, :service_number),
            ClaimNumber: nil,
            VeteranServiceStateDate: nil,
            VeteranServiceEndDate: nil
          }
        end
      end
    end
  end
end
