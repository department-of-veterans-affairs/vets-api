# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::Feb2025
      class FormData
        # Limit the combined Name fields(1. Veterans Name, 2. Appellant Name, 12. Signature)
        # length so that if it does get truncated it's consistent across all 3 fields
        MAX_COMBINED_NAME_FIELD_LENGTH = 164

        # board review options to radio button list index on PDF form
        BOARD_REVIEW_OPTIONS = {
          'direct_review' => 0,
          'evidence_submission' => 1,
          'hearing' => 2
        }.freeze

        BOARD_REVIEW_OPTION_HEARINGS = {
          'central_office' => 0,
          'video_conference' => 1,
          'virtual_hearing' => 2
        }.freeze

        attr_accessor :notice_of_disagreement

        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        delegate :appellant_local_time, :board_review_value, :contestable_issues,
                 :representative, :hearing_type_preference, :requesting_extension?, :extension_reason,
                 :appealing_vha_denial?, :signing_appellant, :veteran, :claimant,
                 to: :notice_of_disagreement

        delegate :first_name, :middle_initial, :last_name, :homeless?,
                 to: :veteran, prefix: true

        delegate :first_name, :middle_initial, :last_name, :homeless?,
                 to: :claimant, prefix: true

        def preferred_phone
          signing_appellant.phone_formatted.to_s
        end

        def mailing_address
          [
            signing_appellant.number_and_street,
            signing_appellant.city,
            signing_appellant.state_code,
            signing_appellant.zip_code,
            signing_appellant.country_code
          ].compact.join(', ')
        end

        def preferred_email
          return 'See attached page for preferred email' if long_preferred_email?

          signing_appellant.email
        end

        def long_preferred_email?
          signing_appellant.email.length > 120
        end

        def veteran_homeless
          signing_appellant.homeless? ? 1 : 'Off'
        end

        def board_review_option
          BOARD_REVIEW_OPTIONS[board_review_value]
        end

        def board_review_option_hearing_type
          BOARD_REVIEW_OPTION_HEARINGS[hearing_type_preference]
        end

        def requesting_extension
          requesting_extension? ? 1 : 'Off'
        end

        def appealing_vha_denial
          appealing_vha_denial? ? 2 : 'Off'
        end

        def overflow_contestable_issues
          contestable_issues.size > 5 ? 1 : 'Off'
        end

        def additional_pages
          contestable_issues.size > 5 || requesting_extension? || long_preferred_email? || long_rep_name? ? 1 : 'Off'
        end

        def rep_name
          return 'See attached page for representative name' if long_rep_name?

          representative&.dig('name') || ''
        end

        def long_rep_name?
          rep = representative&.dig('name') || ''
          rep.length > 60
        end

        def veteran_full_name
          veteran.full_name[0..MAX_COMBINED_NAME_FIELD_LENGTH]
        end

        def claimant_full_name
          claimant.full_name[0..MAX_COMBINED_NAME_FIELD_LENGTH]
        end

        def signature
          "#{signing_appellant.full_name[0...MAX_COMBINED_NAME_FIELD_LENGTH]}\n" \
            '- Signed by digital authentication to api.va.gov'
        end

        def date_signed
          appellant_local_time.strftime('%m/%d/%Y')
        end
      end
    end
  end
end
