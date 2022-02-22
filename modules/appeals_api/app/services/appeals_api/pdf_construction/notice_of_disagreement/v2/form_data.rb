# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V2
      class FormData
        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        delegate :appellant_local_time, :board_review_value, :contestable_issues, :extension_request?,
                 :representative_name, :signing_appellant, :veteran, :veteran_homeless?,
                 to: :notice_of_disagreement

        delegate :first_name, :last_name, :phone_data, :number_and_street, :city, :zip_code,
                 to: :veteran, prefix: true

        def veteran_phone
          veteran.phone_formatted.to_s || 'USE PHONE ON FILE'
        end

        def veteran_email
          veteran.email.presence || 'USE EMAIL ON FILE'
        end

        def veteran_homeless
          veteran_homeless? ? 1 : 'Off'
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

        def additional_pages
          contestable_issues.size > 5 || extension_request? ? 1 : 'Off'
        end

        def signature
          "#{signing_appellant.full_name[0...180]}\n- Signed by digital authentication to api.va.gov"
        end

        def date_signed_mm
          appellant_local_time.strftime '%m'
        end

        def date_signed_dd
          appellant_local_time.strftime '%d'
        end

        def date_signed_yyyy
          appellant_local_time.strftime '%Y'
        end

        def stamp_text
          "#{veteran.last_name.truncate(35)} - #{veteran.file_number}"
        end

        private

        attr_accessor :notice_of_disagreement
      end
    end
  end
end
