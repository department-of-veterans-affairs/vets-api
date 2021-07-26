# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V1
      class FormData
        def initialize(higher_level_review)
          @higher_level_review = higher_level_review
        end

        delegate :first_name, to: :higher_level_review

        delegate :middle_initial, to: :higher_level_review

        delegate :last_name, to: :higher_level_review

        def first_three_ssn
          ssn.first(3)
        end

        def second_two_ssn
          ssn[3..4]
        end

        def last_four_ssn
          ssn.last(4)
        end

        def birth_month
          higher_level_review.birth_mm
        end

        def birth_day
          higher_level_review.birth_dd
        end

        def birth_year
          higher_level_review.birth_yyyy
        end

        delegate :file_number, to: :higher_level_review

        delegate :service_number, to: :higher_level_review

        delegate :insurance_policy_number, to: :higher_level_review

        def claimant_type(index)
          index == 4 ? 1 : 'off'
        end

        def mailing_address_street
          'USE ADDRESS ON FILE'
        end

        def mailing_address_unit_number
          ''
        end

        def mailing_address_city
          ''
        end

        def mailing_address_state
          ''
        end

        def mailing_address_country
          ''
        end

        def mailing_address_zip_first_5
          ''
        end

        def mailing_address_zip_last_4
          ''
        end

        def veteran_phone_number
          higher_level_review.veteran_phone_number.presence ||
            'USE PHONE ON FILE'
        end

        def veteran_email
          higher_level_review.email.presence ||
            'USE EMAIL ON FILE'
        end

        def benefit_type(benefit_type)
          return 'Off' unless higher_level_review.benefit_type == benefit_type

          benefit_type_form_codes[benefit_type]
        end

        def same_office
          higher_level_review.same_office ? 1 : 'Off'
        end

        def informal_conference
          higher_level_review.informal_conference ? 1 : 'Off'
        end

        def informal_conference_times(time)
          higher_level_review.informal_conference_times.include?(time) ? 1 : 'Off'
        end

        def rep_name_and_phone_number
          rep = higher_level_review.informal_conference_rep

          "#{rep&.dig('name')} #{higher_level_review.informal_conference_rep_phone}"
        end

        def signature
          higher_level_review.full_name
        end

        delegate :date_signed, to: :higher_level_review

        delegate :contestable_issues, to: :higher_level_review

        private

        attr_reader :higher_level_review

        def ssn
          higher_level_review.ssn
        end

        def benefit_type_form_codes
          {
            'compensation' => 1,
            'pension_survivors_benefits' => 2,
            'voc_rehab' => 3,
            'fiduciary' => 4,
            'education' => 5,
            'vha' => 6,
            'loan_guaranty' => 7,
            'insurance' => 8,
            'nca' => 9
          }
        end
      end
    end
  end
end
