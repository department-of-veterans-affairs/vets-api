module AppealsApi
  module PdfConstruction
    module NoticeOfDisagreement
      class Structure
        def initialize(notice_of_disagreement)
          @notice_of_disagreement = notice_of_disagreement
        end

        def form_fill
          options = {
            form_fields.veteran_name                      => form_data.veteran_name,
            form_fields.veteran_ssn                       => form_data.veteran_ssn,
            form_fields.veteran_file_number               => form_data.veteran_file_number,
            form_fields.date_signed                       => form_data.veteran_dob,
            form_fields.mailing_address_number_and_street => form_data.mailing_address_number_and_street,
            form_fields.homeless?                         => form_data.homeless?,
            form_fields.preferred_phone                   => form_data.veteran_name,
            form_fields.preferred_email                   => form_data.veteran_name,
            form_fields.direct_review?                    => form_data.veteran_name,
            form_fields.evidence_submission?              => form_data.veteran_name,
            form_fields.hearing?                          => form_data.veteran_name,
            form_fields.additional_pages?                 => form_data.veteran_name,
            form_fields.soc_opt_in?                       => form_data.veteran_name,
            form_fields.signature                         => form_data.signature,
            form_fields.date_signed                       => form_data.veteran_name,
          }

          fill_first_five_issue_dates!(options)
        end

        def additional_fields

        end

        def form_title
          '10182'
        end

        private

        def form_fields
          @form_fields ||= NoticeOfDisagreement::FormFields.new
        end

        def form_data
          @form_data ||= NoticeOfDisagreement::FormData.new(@notice_of_disagreement)
        end

        def fill_first_five_issue_dates!(options)
          form_data.contestable_issues.take(5).each_with_index do |issue, index|
            options[form_fields.issue_table_decision_date(index)] = issue['attributes']['decisionDate']
          end

          options
        end

        def method_missing(method, *args, &block)
          if @notice_of_disagreement.respond_to?(method)
            @notice_of_disagreement.send(method)
          else
            super
          end
        end
      end
    end
  end
end
