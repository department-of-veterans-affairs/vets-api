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
          formatted_full_name(first_name, middle_initial, last_name)
        end

        def claimant_name
          formatted_full_name(claimant_first_name, claimant_middle_initial, claimant_last_name)
        end

        def veteran_ssn
          header_field_as_string('X-VA-SSN')
        end

        def veteran_file_number
          header_field_as_string('X-VA-File-Number')
        end

        def veteran_dob
          dob
        end

        def claimant_dob
          header_field_as_string 'X-VA-Claimant-Birth-Date'
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
          notice_of_disagreement.board_review_option == 'direct_review' ? 1 : 'Off'
        end

        def evidence_submission
          notice_of_disagreement.board_review_option == 'evidence_submission' ? 1 : 'Off'
        end

        def hearing
          notice_of_disagreement.board_review_option == 'hearing' ? 1 : 'Off'
        end

        def extra_contestable_issues
          contestable_issues.size > 5 ? 1 : 'Off'
        end

        def soc_opt_in
          notice_of_disagreement.form_data&.dig('data', 'attributes', 'socOptIn') ? 1 : 'Off'
        end

        def signature
          # 180 characters is the max allowed by the Name field on the pdf
          name = claimant_name.presence || veteran_name
          "#{name[0...180]}\n- Signed by digital authentication to api.va.gov"
        end

        def date_signed
          timezone = notice_of_disagreement.form_data&.dig('data', 'attributes', 'timezone').presence&.strip || 'UTC'
          time = notice_of_disagreement.created_at.in_time_zone(timezone)
          time.strftime('%Y-%m-%d')
        end

        def contestable_issues
          notice_of_disagreement.form_data&.dig('included')
        end

        def representative_name
          notice_of_disagreement.representative_name.to_s
        end

        delegate :hearing_type_preference, to: :notice_of_disagreement

        private

        attr_accessor :notice_of_disagreement

        def formatted_full_name(first, middle, last)
          middle = "#{middle}." if middle.present?

          [
            first,
            middle,
            last
          ].map(&:presence).compact.join(' ')
        end

        def first_name
          header_field_as_string 'X-VA-First-Name'
        end

        def middle_initial
          header_field_as_string 'X-VA-Middle-Initial'
        end

        def last_name
          header_field_as_string 'X-VA-Last-Name'
        end

        def claimant_first_name
          header_field_as_string 'X-VA-Claimant-First-Name'
        end

        def claimant_middle_initial
          header_field_as_string 'X-VA-Claimant-Middle-Initial'
        end

        def claimant_last_name
          header_field_as_string 'X-VA-Claimant-Last-Name'
        end

        def dob
          header_field_as_string 'X-VA-Birth-Date'
        end

        def header_field_as_string(key)
          header_field(key).to_s.strip
        end

        def header_field(key)
          notice_of_disagreement.auth_headers&.dig(key)
        end
      end
    end
  end
end
