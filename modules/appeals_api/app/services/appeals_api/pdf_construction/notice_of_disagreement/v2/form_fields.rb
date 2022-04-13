# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::V2
      class FormFields
        def veteran_file_number
          'F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
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

        def preferred_email
          'F[0].Page_1[0].PreferredEmail[0]'
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

        def central_office_hearing
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[4]'
        end

        def video_conference_hearing
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[5]'
        end

        def virtual_tele_hearing
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[6]'
        end

        def requesting_extension
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[7]'
        end

        def appealing_vha_denial
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[8]'
        end

        def extra_contestable_issues
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[9]'
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

        def additional_issues
          'F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[9]'
        end
      end
    end
  end
end
