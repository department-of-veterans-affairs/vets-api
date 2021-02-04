# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V1
      class FormData
        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        delegate :mailing_address, to: :notice_of_disagreement

        def veteran_name
          name('Veteran')
        end

        def veteran_ssn
          header_field_as_string('X-VA-Veteran-SSN')
        end

        def veteran_file_number
          header_field_as_string('X-VA-Veteran-File-Number')
        end

        def veteran_dob
          dob 'Veteran'
        end

        def homeless
          notice_of_disagreement.veteran_homeless? ? 1 : 'Off'
        end

        def preferred_phone
          notice_of_disagreement.phone
        end

        def preferred_email
          notice_of_disagreement.email
        end

        def direct_review
          board_review_option == 'direct_review' ? 1 : 'Off'
        end

        def evidence_submission
          board_review_option == 'evidence_submission' ? 1 : 'Off'
        end

        def hearing
          board_review_option == 'hearing' ? 1 : 'Off'
        end

        def extra_contestable_issues
          contestable_issues.size > 5 ? 1 : 'Off'
        end

        def soc_opt_in
          notice_of_disagreement.form_data&.dig('data', 'attributes', 'socOptIn') ? 1 : 'Off'
        end

        def signature
          first_last = [first_name('Veteran'), last_name('Veteran')]
          formatted_name = first_last.map(&:presence).compact.map(&:strip).join(' ')
          auth_statement = 'signed by digital authentication to api.va.gov'

          "#{formatted_name} - #{auth_statement}"
        end

        def date_signed
          timezone = notice_of_disagreement.form_data&.dig('data', 'attributes', 'timezone').presence&.strip || 'UTC'
          time = Time.now.in_time_zone(timezone)
          time.strftime('%Y-%m-%d')
        end

        def contestable_issues
          notice_of_disagreement.form_data&.dig('included')
        end

        def stamp_text
          "#{last_name('Veteran')} - #{veteran_ssn.last(4)}"
        end

        def representatives_name
          notice_of_disagreement.veteran_representative.to_s
        end

        delegate :hearing_type_preference, to: :notice_of_disagreement

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
          notice_of_disagreement.auth_headers&.dig(key)
        end

        def board_review_option
          notice_of_disagreement.form_data&.dig('data', 'attributes', 'boardReviewOption')
        end
      end
    end
  end
end
