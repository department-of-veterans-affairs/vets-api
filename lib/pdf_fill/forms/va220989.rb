# frozen_string_literal: true

module PdfFill
  module Forms
    class Va220989 < FormBase
      include FormHelper

      KEY = {
        'applicantName' => { key: 'applicant_name' },
        'vaFileNumber' => { key: 'va_file_number' },
        'mailingAddress' => { key: 'mailing_address' },
        'emailAddress' => { key: 'email_address' },
        'homePhone' => { key: 'home_phone' },
        'mobilePhone' => { key: 'mobile_phone' },
        'schoolWasClosed' => { key: 'school_was_closed' },
        'closedSchoolNameAndAddress' => { key: 'closed_school_name_and_address' },
        'didCompleteProgramOfStudy' => { key: 'did_complete_program_of_study' },
        'didReceiveCredit' => { key: 'did_receive_credit' },
        'wasEnrolledWhenSchoolClosed' => { key: 'was_enrolled_when_school_closed' },
        'wasOnApprovedLeave' => { key: 'was_on_approved_leave' },
        'withdrewPriorToClosing' => { key: 'withdrew_prior_to_closing' },
        'dateOfWithdraw' => { key: 'date_of_withdraw' },
        'enrolledAtNewSchool' => { key: 'enrolled_at_new_school' },
        'newSchoolAndProgramName' => { key: 'new_school_and_program_name' },
        'isUsingTeachoutAgreement' => { key: 'is_using_teachout_agreement' },
        'newSchoolGrants12OrMoreCredits' => { key: 'new_school_grants_12_or_more_credits' },
        'schoolDidTransferCredits' => { key: 'school_did_transfer_credits' },
        'lastDateOfAttendance' => { key: 'last_date_of_attendance' },
        'remarks' => { key: 'remarks' },
        'attestationName' => { key: 'attestation_name' },
        'attestationDate' => { key: 'attestation_date' },
        'statementOfTruthSignature' => { key: 'signature' },
        'dateSigned' => { key: 'date_signed' }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        format_applicant_info(form_data)
        format_radio_inputs(form_data)
        format_old_school_name_and_address(form_data)
        format_new_school_and_program(form_data)
        format_dates(form_data)

        form_data
      end

      def format_applicant_info(form_data)
        form_data['applicantName'] = combine_full_name(form_data['applicantName'])
        form_data['vaFileNumber'] = form_data['vaFileNumber'].presence || form_data['ssn']
        form_data['mailingAddress'] = combine_full_address(form_data['mailingAddress'])
      end

      def format_radio_inputs(form_data)
        %w[schoolWasClosed
           didCompleteProgramOfStudy
           didReceiveCredit
           wasEnrolledWhenSchoolClosed
           wasOnApprovedLeave
           withdrewPriorToClosing
           enrolledAtNewSchool
           isUsingTeachoutAgreement
           newSchoolGrants12OrMoreCredits
           schoolDidTransferCredits].each do |key|
          form_data[key] = form_data[key] ? 'YES' : 'NO'
        end
      end

      def format_old_school_name_and_address(form_data)
        form_data['closedSchoolNameAndAddress'] = <<~SCHOOL
          #{form_data['closedSchoolName']}
          #{combine_full_address_extras(form_data['closedSchoolAddress'])}
        SCHOOL
      end

      def format_new_school_and_program(form_data)
        if form_data['enrolledAtNewSchool'] == 'YES'
          form_data['newSchoolAndProgramName'] = <<~PROGRAM
            #{form_data['newSchoolName']}
            #{form_data['newProgramName']}
          PROGRAM
        end
      end

      def format_dates(form_data)
        form_data['dateOfWithdraw'] = format_date(form_data['dateOfWithdraw'])
        form_data['lastDateOfAttendance'] = format_date(form_data['lastDateOfAttendance'])
        form_data['attestationDate'] = format_date(form_data['attestationDate'])
        form_data['dateSigned'] = format_date(form_data['dateSigned'], '%m,%d,%Y')
      end

      def format_date(date_string, format_str = '%m/%d/%Y')
        Date.parse(date_string).strftime(format_str)
      rescue
        date_string
      end
    end
  end
end
