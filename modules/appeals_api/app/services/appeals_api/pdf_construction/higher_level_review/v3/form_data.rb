# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V3
        class FormData
          BENEFIT_TYPE_CODES = {
            # Important: the order of these entries reflects the indices of the form fields
            'education' => 5,
            'nationalCemeteryAdministration' => 9,
            'veteransHealthAdministration' => 6,
            'lifeInsurance' => 8,
            'loanGuaranty' => 7,
            'fiduciary' => 4,
            'veteranReadinessAndEmployment' => 3,
            'pensionSurvivorsBenefits' => 2,
            'compensation' => 1
          }.freeze

          MAX_SIGNATURE_LENGTH = 180

          def initialize(higher_level_review)
            @higher_level_review = higher_level_review
          end

          delegate :veteran, :claimant, :informal_conference_rep, :contestable_issues, :signing_appellant,
                   :appellant_local_time,
                   to: :higher_level_review

          delegate :first_name, :middle_initial, :last_name, :file_number, :insurance_policy_number,
                   :number_and_street, :city, :state_code, :country_code, :zip_code,
                   to: :veteran, prefix: true

          delegate :first_name, :middle_initial, :last_name, :number_and_street, :city, :state_code,
                   :country_code, :zip_code, :email,
                   to: :claimant, prefix: true

          def veteran_phone_area_code
            veteran.phone_data&.dig('areaCode') if veteran_domestic_phone?
          end

          def veteran_phone_prefix
            veteran.phone_data&.dig('phoneNumber')&.first(3) if veteran_domestic_phone?
          end

          def veteran_phone_line_number
            veteran.phone_data&.dig('phoneNumber')&.last(4) if veteran_domestic_phone?
          end

          def veteran_international_phone
            veteran.phone_formatted.to_s unless veteran_domestic_phone?
          end

          def veteran_email
            veteran.email.presence || 'USE EMAIL ON FILE'
          end

          def veteran_ssn_first_three
            veteran.ssn.first(3)
          end

          def veteran_ssn_middle_two
            veteran.ssn&.slice(3..4)
          end

          def veteran_ssn_last_four
            veteran.ssn.last(4)
          end

          def veteran_dob_month
            veteran.birth_date.strftime '%m'
          end

          def veteran_dob_day
            veteran.birth_date.strftime '%d'
          end

          def veteran_dob_year
            veteran.birth_date.strftime '%Y'
          end

          def veteran_homeless
            veteran.homeless? ? 1 : 'Off'
          end

          def claimant_phone_area_code
            claimant.phone_data&.dig('areaCode') if claimant_domestic_phone?
          end

          def claimant_phone_prefix
            claimant.phone_data&.dig('phoneNumber')&.first(3) if claimant_domestic_phone?
          end

          def claimant_phone_line_number
            claimant.phone_data&.dig('phoneNumber')&.last(4) if claimant_domestic_phone?
          end

          def claimant_international_phone
            claimant.phone_formatted.to_s unless claimant_domestic_phone?
          end

          def claimant_ssn_first_three
            claimant.ssn&.first(3)
          end

          def claimant_ssn_middle_two
            claimant.ssn&.slice(3..4)
          end

          def claimant_ssn_last_four
            claimant.ssn&.last(4)
          end

          def claimant_dob_month
            claimant.birth_date&.strftime '%m'
          end

          def claimant_dob_day
            claimant.birth_date&.strftime '%d'
          end

          def claimant_dob_year
            claimant.birth_date&.strftime '%Y'
          end

          def benefit_type_code(benefit_type)
            return 'Off' unless higher_level_review.benefit_type == benefit_type

            BENEFIT_TYPE_CODES[benefit_type]
          end

          def informal_conference
            higher_level_review.informal_conference ? 1 : 'Off'
          end

          # rubocop:disable Naming/VariableNumber
          def conference_8_to_12
            informal_conference_time('veteran', '800-1200 ET')
          end

          def conference_12_to_1630
            informal_conference_time('veteran', '1200-1630 ET')
          end

          def conference_rep_8_to_12
            informal_conference_time('representative', '800-1200 ET')
          end

          def conference_rep_12_to_1630
            informal_conference_time('representative', '1200-1630 ET')
          end
          # rubocop:enable Naming/VariableNumber

          def rep_first_name
            higher_level_review.informal_conference_rep&.dig('firstName')
          end

          def rep_last_name
            higher_level_review.informal_conference_rep&.dig('lastName')
          end

          def rep_phone_area_code
            return unless rep_domestic_phone?

            higher_level_review.informal_conference_rep_phone.area_code
          end

          def rep_phone_prefix
            return unless rep_domestic_phone?

            higher_level_review.informal_conference_rep_phone.phone_number&.first(3)
          end

          def rep_phone_line_number
            return unless rep_domestic_phone?

            higher_level_review.informal_conference_rep_phone.phone_number&.last(4)
          end

          def rep_phone_extension
            # Unlike with the veteran's phone fields, there is enough space to the right of the domestic claimant phone
            # fields that we can print the extension next to them instead of filling the international number field as
            # a fallback.
            return unless rep_domestic_phone?

            ext = higher_level_review.informal_conference_rep_phone.phone_number_ext
            "x#{ext}" if ext.present?
          end

          def rep_international_phone
            higher_level_review.informal_conference_rep_phone.to_s unless rep_domestic_phone?
          end

          def rep_email
            higher_level_review.informal_conference_rep&.dig('email')
          end

          def veteran_claimant_signature
            "#{signing_appellant.full_name[0...MAX_SIGNATURE_LENGTH]}\n- Signed by digital authentication to api.va.gov"
          end

          def veteran_claimant_date_signed_month
            appellant_local_time.strftime '%m'
          end

          def veteran_claimant_date_signed_day
            appellant_local_time.strftime '%d'
          end

          def veteran_claimant_date_signed_year
            appellant_local_time.strftime '%Y'
          end

          # NOTE: Rep signature is not yet supported - only veteran/claimant

          private

          attr_reader :higher_level_review

          def veteran_domestic_phone?
            # A domestic phone number will be filled in the international field if it has an extension,
            # because there is not enough space to fit an extension after the domestic fields.
            veteran.domestic_phone? && veteran.phone_data&.dig('phoneNumberExt').blank?
          end

          def claimant_domestic_phone?
            # As with the veteran phone, a domestic claimant phone is treated as international if there's an extension.
            claimant.domestic_phone? && claimant.phone_data&.dig('phoneNumberExt').blank?
          end

          def rep_domestic_phone?
            country_code = higher_level_review.informal_conference_rep_phone&.country_code
            country_code.blank? || country_code == '1'
          end

          def informal_conference_time(contact, time)
            return 'Off' if contact != higher_level_review.informal_conference_contact
            return 'Off' if time != higher_level_review.informal_conference_time

            1
          end
        end
      end
    end
  end
end
