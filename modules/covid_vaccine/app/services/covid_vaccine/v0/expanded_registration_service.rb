# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationService
      def register(submission)
        raw_form_data = submission.raw_form_data
        # Conditions where we should not send data to vetext (unless record is > 24 hours old):
        # 1 - no preferred location in raw_form_data and no facility found for zip_code: manual intervention
        # 2 - no ICN found in MPI: retry
        # 3 - Station ID returned from MPI is different than preferred location: retry

        # preferred facility will either be in eligibility_info, or raw_form_data. If its in neither one,
        # for the purposes of this register method we should not be fetching facilities and trying to reconcile;
        # instead we will set the state to :enrollment_out_of_band and raise an exception

        facility = handle_facility(submission) || []
        # MPI Query must succeed and return ICN and expected facilityID before we send this data to backend service
        # Application will retry for 24 hours
        # if records are > 24 hours old, we will send to VeText service without an ICN or facility match
        mpi_attributes = attributes_from_mpi(raw_form_data, facility[0..2], submission.id, submission.created_at)
        return if mpi_attributes.empty?

        if submission.state != 'enrollment_complete'
          submission.created_at <= 1.day.ago ? submission.failed_enrollment! : submission.detected_enrollment!
        end

        vetext_attributes = transform_form_data(raw_form_data, facility, mpi_attributes)
        submit_and_save(vetext_attributes, submission)
      end

      private

      def submit_and_save(attributes, submission)
        # TODO: error handling
        audit_log(attributes)
        response = submit(attributes)
        Rails.logger.info("Covid_Vaccine_Expanded Vetext Response: #{response}")
        elig_info_icn = { 'patient_icn': attributes[:patient_icn] }
        elig_info_icn.merge!(submission.eligibility_info) unless submission.eligibility_info.nil?
        state = get_state(attributes, submission)
        submission.update!(vetext_sid: response[:sid], form_data: attributes, state:,
                           eligibility_info: elig_info_icn)
        submission
      end

      def submit(attributes)
        CovidVaccine::V0::VetextService.new.put_vaccine_registry(attributes)
      end

      def audit_log(attributes)
        log_attrs = {
          user_type: attributes[:applicant_type],
          zip_code: attributes[:zip_code],
          has_phone: attributes[:phone].present?,
          has_email: attributes[:email].present?,
          has_icn: attributes[:patient_icn].present?,
          has_facility: attributes[:sta3n].present? || attributes[:sta6a].present?,
          is_expanded_eligibility: true
        }
        Rails.logger.info('Covid_Vaccine_Expanded Submission', log_attrs)
      end

      def get_state(attributes, submission)
        return 'registered' if submission.state == 'enrollment_complete'

        attributes[:patient_icn].blank? ? 'registered_no_icn' : 'registered_no_facility'
      end

      def handle_facility(submission)
        facility = submission&.eligibility_info&.fetch('preferred_facility', nil) ||
                   submission.raw_form_data['preferred_facility']&.delete_prefix('vha_')
        handle_no_facility_error(submission) if facility.blank?
        facility
      end

      # This occurs when no preferred_facility is passed with the form data and will be
      # resolved after a 24 hour delay in same way MPI facility issues resolve
      def handle_no_facility_error(submission)
        Rails.logger.info(
          "#{self.class.name}:No preferred facility selected",
          submission: submission.id,
          submission_date: submission.created_at
        )
      end

      def transform_form_data(raw_form_data, facility, mpi_attributes)
        transformed_data = other_form_attributes(raw_form_data)
        transformed_data.merge!(location_contact_information(raw_form_data, facility))
        transformed_data.merge!(demographics(raw_form_data))
        transformed_data.merge!(mpi_attributes).compact!
        transformed_data
      end

      def demographics(form_data)
        {
          first_name: form_data['first_name'],
          last_name: form_data['last_name'],
          date_of_birth: form_data['birth_date'],
          patient_ssn: form_data['ssn'],
          birth_sex: form_data['birth_sex'],
          applicant_type: form_data['applicant_type']
        }
      end

      def location_contact_information(form_data, facility)
        full_address = [form_data['address_line1'], form_data['address_line2'],
                        form_data['address_line3']].join(' ').strip
        {
          address: full_address,
          city: form_data['city'],
          state: form_data['state_code'],
          zip_code: form_data['zip_code'],
          phone: form_data['phone'],
          email: form_data['email_address'] || '',
          sms_acknowledgement: form_data['sms_acknowledgement'] || false,
          sta3n: facility[0..2],
          sta6a: facility.length > 3 ? facility : ''
        }
      end

      def other_form_attributes(form_data)
        service_date_range = form_data['date_range'] ? form_data['date_range'].to_a.flatten.join(' ') : ''
        {
          vaccine_interest: 'INTERESTED',
          privacy_agreement_accepted: form_data['privacy_agreement_accepted'],
          last_branch_of_service: form_data['last_branch_of_service'] || '',
          service_date_range:,
          character_of_service: form_data['character_of_service'] || '',
          enhanced_eligibility: true,
          authenticated: false
        }
      end

      def attributes_from_mpi(form_data, sta3n, submission_id, submission_date)
        response = MPI::Service.new.find_profile_by_attributes(first_name: form_data['first_name'],
                                                               last_name: form_data['last_name'],
                                                               birth_date: form_data['birth_date'],
                                                               ssn: form_data['ssn'])
        if response.ok?
          handle_mpi_response_success(response, sta3n, submission_id, submission_date)
        else
          handle_mpi_response_fail(submission_id, submission_date)
        end
      end

      def handle_mpi_response_success(response, sta3n, submission_id, submission_date)
        if response.profile&.vha_facility_ids&.include? sta3n
          {
            patient_icn: response.profile.icn
          }
        else
          handle_mpi_errors("no matching facility found for #{sta3n}", submission_id, submission_date)
          submission_date <= 1.day.ago ? { patient_icn: response.profile.icn } : {}
        end
      end

      def handle_mpi_response_fail(submission_id, submission_date)
        handle_mpi_errors('no ICN found', submission_id, submission_date)
        submission_date <= 1.day.ago ? { patient_icn: '' } : {}
      end

      def handle_mpi_errors(error, id, date)
        Rails.logger.info(
          "#{self.class.name}:Error in MPI Lookup",
          mpi_error: error,
          submission: id,
          submission_date: date
        )
      end
    end
  end
end
