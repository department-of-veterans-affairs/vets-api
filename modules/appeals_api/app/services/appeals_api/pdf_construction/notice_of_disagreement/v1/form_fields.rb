# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V1
      class FormFields
        def veteran_name
          'F[0].Page_1[0].VeteransFirstName[0]'
        end

        def veteran_ssn
          'F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
        end

        def veteran_file_number
          'F[0].Page_1[0].VAFileNumber[0]'
        end

        def veteran_dob
          'F[0].Page_1[0].DateSigned[0]'
        end

        def claimant_dob
          'F[0].Page_1[0].DateSigned[1]'
        end

        def mailing_address
          'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]'
        end

        def homeless
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[0]'
        end

        def preferred_phone
          'F[0].Page_1[0].PreferredPhoneNumber[0]'
        end

        def direct_review
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[1]'
        end

        def evidence_submission
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[2]'
        end

        def hearing
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[3]'
        end

        def extra_contestable_issues
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[4]'
        end

        def soc_opt_in
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[5]'
        end

        def signature
          'F[0].Page_1[0].SignatureOfClaimant_AuthorizedRepresentative[0]'
        end

        def date_signed
          'F[0].Page_1[0].DateSigned[2]'
        end

        def issue_table_decision_date(index)
          "F[0].Page_1[0].Percentage2[#{index}]"
        end
      end
    end
  end
end
