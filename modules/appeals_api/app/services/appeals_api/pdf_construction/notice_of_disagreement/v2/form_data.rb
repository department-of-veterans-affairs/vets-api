# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V2
      class FormData
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
          veteran.homeless? ? 1 : 'Off'
        end

        def direct_review
          board_review_value == 'direct_review' ? 1 : 'Off'
        end

        def evidence_submission
          board_review_value == 'evidence_submission' ? 1 : 'Off'
        end

        def hearing
          board_review_value == 'hearing' ? 1 : 'Off'
        end

        def central_office_hearing
          hearing_type_preference == 'central_office' ? 1 : 'Off'
        end

        def video_conference_hearing
          hearing_type_preference == 'video_conference' ? 1 : 'Off'
        end

        def virtual_tele_hearing
          hearing_type_preference == 'virtual_hearing' ? 1 : 'Off'
        end

        def requesting_extension
          requesting_extension? ? 1 : 'Off'
        end

        def appealing_vha_denial
          appealing_vha_denial? ? 1 : 'Off'
        end

        def extra_contestable_issues
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

        def signature
          # TODO: need to eventually handle representative signature here as well
          "#{signing_appellant.full_name[0...180]}\n- Signed by digital authentication to api.va.gov"
        end

        def date_signed
          appellant_local_time.strftime('%m/%d/%Y')
        end

        private

        attr_accessor :notice_of_disagreement
      end
    end
  end
end
