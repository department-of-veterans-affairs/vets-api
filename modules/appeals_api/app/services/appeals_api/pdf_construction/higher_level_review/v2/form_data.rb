# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V2
      class FormData
        def initialize(higher_level_review)
          @higher_level_review = higher_level_review
        end

        delegate :contestable_issues, :date_signed_v2_mm, :date_signed_v2_dd, :date_signed_v2_yyyy,
                 :signing_appellant, :signature_v2, :claimant, :veteran,
                 to: :higher_level_review

        delegate :first_name, :last_name, :number_and_street, :city, :zip_code,
                 to: :veteran, prefix: true

        delegate :first_name, :last_name, :number_and_street, :city, :zip_code, :email,
                 to: :claimant, prefix: true

        def veteran_email
          veteran.email.presence || 'USE EMAIL ON FILE'
        end

        def first_three_ssn
          ssn.first(3)
        end

        def second_two_ssn
          ssn[3..4]
        end

        def last_four_ssn
          ssn.last(4)
        end

        def veteran_homeless
          higher_level_review.veteran_homeless? ? 1 : 'Off'
        end

        def veteran_phone_extension
          ext = higher_level_review.veteran_phone_data&.dig('phoneNumberExt')

          return '' if veteran_country_code != '1' || ext.blank?

          "x#{ext}"
        end

        def veteran_phone_area_code
          return if veteran_country_code != '1'

          higher_level_review.veteran_phone_data&.dig('areaCode')
        end

        def veteran_phone_prefix
          return if veteran_country_code != '1'

          higher_level_review.veteran_phone_data&.dig('phoneNumber')&.first(3)
        end

        def veteran_phone_line_number
          return if veteran_country_code != '1'

          higher_level_review.veteran_phone_data['phoneNumber']&.last(4)
        end

        def veteran_phone_international_number
          return if veteran_country_code == '1'

          higher_level_review.veteran_phone_number.presence ||
            'USE PHONE ON FILE'
        end

        def veteran_country_code
          higher_level_review.veteran_phone_data&.dig('countryCode')
        end

        def benefit_type(benefit_type)
          return 'Off' unless higher_level_review.benefit_type == benefit_type

          benefit_type_form_codes[benefit_type]
        end

        def informal_conference
          higher_level_review.informal_conference ? 1 : 'Off'
        end

        def informal_conference_time(contact, time)
          return 'Off' if contact != higher_level_review.informal_conference_contact
          return 'Off' if time != higher_level_review.informal_conference_time

          1
        end

        def rep_first_name
          higher_level_review.informal_conference_rep&.dig('firstName') || ''
        end

        def rep_last_name
          higher_level_review.informal_conference_rep&.dig('lastName') || ''
        end

        def rep_phone_area_code
          return if rep_country_code != '1'

          higher_level_review.informal_conference_rep_phone.area_code || ''
        end

        def rep_phone_prefix
          return if rep_country_code != '1'

          higher_level_review.informal_conference_rep_phone.phone_number&.first(3) || ''
        end

        def rep_phone_line_number
          return if rep_country_code != '1'

          higher_level_review.informal_conference_rep_phone.phone_number&.last(4) || ''
        end

        def rep_email
          higher_level_review.informal_conference_rep&.dig('email') || ''
        end

        def rep_domestic_ext
          ext = higher_level_review.informal_conference_rep_phone.phone_number_ext

          # if the number is international, it gets added to that output
          return '' if rep_country_code != '1' || ext.blank?

          "x#{ext}"
        end

        def rep_international_number
          return '' if rep_country_code == '1'

          higher_level_review.informal_conference_rep_phone.to_s
        end

        def rep_country_code
          higher_level_review.informal_conference_rep_phone.country_code || '1'
        end

        def soc_opt_in
          higher_level_review.soc_opt_in ? 1 : 'Off'
        end

        def soc_date_text(issue)
          date = issue.soc_date_formatted

          return '' unless date

          "SOC/SSOC Date: #{date}"
        end

        def date_signed
          signing_appellant.date_signed.strftime
        end

        def stamp_text
          "#{signing_appellant.last_name.truncate(35)} - #{veteran.ssn.last(4)}"
        end

        private

        attr_reader :higher_level_review

        def ssn
          higher_level_review.ssn
        end

        def benefit_type_form_codes
          {
            'compensation' => 1,
            'pensionSurvivorsBenefits' => 2,
            'readinessAndEmployment' => 3,
            'fiduciary' => 4,
            'education' => 5,
            'veteransHealthAdministration' => 6,
            'loanGuaranty' => 7,
            'lifeInsurance' => 8,
            'nationalCemeteryAdministration' => 9
          }
        end
      end
    end
  end
end
