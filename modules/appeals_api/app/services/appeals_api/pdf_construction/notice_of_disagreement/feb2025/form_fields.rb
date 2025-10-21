# frozen_string_literal: true

module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement::Feb2025
      class FormFields
        def veteran_file_number
          'form1[0].#subform[0].VETERANSFILENUMBER[0]'
        end

        def veteran_dob
          'form1[0].#subform[0].DOBVeteran[0]'
        end

        def claimant_dob
          'form1[0].#subform[0].MyDOB[0]'
        end

        def mailing_address
          'form1[0].#subform[0].MYPREFERREDMAILINGADDRESS[0]'
        end

        def homeless
          'form1[0].#subform[0].IAMEXPERIENCINGHOMELESSNESS[0]'
        end

        def preferred_phone
          'form1[0].#subform[0].PREFERREDPHONENO[0]'
        end

        def preferred_email
          'form1[0].#subform[0].MYPREFERREDE-MAILADDRESS[0]'
        end

        def board_review_option
          'form1[0].#subform[0].RadioButtonList[0]'
        end

        def board_review_option_hearing_type
          'form1[0].#subform[0].RadioButtonList[1]'
        end

        def direct_review
          'form1[0].#subform[0].RadioButtonList[0]'
        end

        def evidence_submission
          'form1[0].#subform[0].RadioButtonList[0]'
        end

        def requesting_extension
          'form1[0].#subform[0].SpecificIssues[0]'
        end

        def appealing_vha_denial
          'form1[0].#subform[0].SpecificIssues[1]'
        end

        def extra_contestable_issues
          'form1[0].#subform[0].AdditionalIssues[0]'
        end

        def signature
          'F[0].Page_1[0].SignatureOfClaimant_AuthorizedRepresentative[0]'
        end

        def date_signed
          'form1[0].#subform[0].DateSigned[0]'
        end

        def issue_table_decision_date(index)
          index += 1
          "form1[0].#subform[0].Table1[0].Row#{index}[0].DateDecision#{index}[0]"
        end

        def additional_issues
          'form1[0].#subform[0].AdditionalIssues[0]'
        end
      end
    end
  end
end
