# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      class FormData
        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        def veteran_name
          name('Veteran')
        end

        def veteran_ssn
          header_field_as_string('X-VA-Veteran-SSN')
        end

        def veteran_file_number
          header_field_as_string('X-VA-Veteran-File-Number')
        end

        def mailing_address_number_and_street
          'USE ADDRESS ON FILE'
        end

        def homeless?
          @notice_of_disagreement.veteran_homeless_state ? 1 : 'Off'
        end

        def preferred_phone
          'USE PHONE NUMBER ON FILE'
        end

        def preferred_email
          'USE EMAIL ON FILE'
        end

        def direct_review?
          board_review_option == 'direct_review' ? 1 : 'Off'
        end

        def evidence_submission?
          board_review_option == 'evidence_submission' ? 1 : 'Off'
        end

        def hearing?
          board_review_option == 'hearing' ? 1 : 'Off'
        end

        def additional_pages?
          contestable_issues.size > 5 ? 1 : 'Off'
        end

        def soc_opt_in?
          @notice_of_disagreement.form_data&.dig('data', 'attributes', 'socOptIn') ? 1 : 'Off'
        end

        def signature
          [first_name('Veteran'), last_name('Veteran')].map(&:presence).compact.map(&:strip).join(' ')
        end

        def date_signed
          veterans_timezone = @notice_of_disagreement.form_data&.dig('data', 'attributes', 'timezone').presence&.strip
          time = veterans_timezone.present? ? Time.now.in_time_zone(veterans_timezone) : Time.now.utc
          time.strftime('%Y-%m-%d')
        end

        def veteran_dob
          dob 'Veteran'
        end

        def hearing_type_preference
          @notice_of_disagreement.hearing_type_preference
        end


        def representatives_name
          @notice_of_disagreement.veteran_representative
        end

        def board_review_option
          @notice_of_disagreement.form_data&.dig('data', 'attributes', 'boardReviewOption')
        end

        def contestable_issues
          @notice_of_disagreement.form_data&.dig('included')
        end

        private

        attr_accessor :notice_of_disagreement

        def name(who)
          initial = middle_initial(who)
          initial = "#{initial}." if initial.size.positive?

          [
            first_name(who),
            initial,
            last_name(who)
          ].map(&:presence).compact.map(&:strip).join(' ')
        end

        def first_name(who)
          header_field_as_string "X-VA-#{who}-First-Name"
        end

        def middle_initial(who)
          header_field_as_string "X-VA-#{who}-Middle-Initial"
        end

        def last_name(who)
          header_field_as_string "X-VA-#{who}-Last-Name"
        end

        def dob(who)
          header_field_as_string "X-VA-#{who}-Birth-Date"
        end

        def header_field_as_string(key)
          header_field(key).to_s.strip
        end

        def header_field(key)
          @notice_of_disagreement.auth_headers&.dig(key)
        end

        def veteran_last_name
          last_name 'Veteran'
        end

        def veteran_safe_ssn
          header_field_as_string('X-VA-Veteran-SSN').last(4)
        end
      end
    end
  end
end
