# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationService
      REQUIRED_QUERY_TRAITS = %w[first_name last_name birth_date ssn].freeze

      def register(submission, user_type, record_id)
        raw_form_data = submission.raw_form_data

        # Conditions where we should not send data to vetext:
        # 1 - no preferred location in raw_form_data and no facility found for zip_code: manual intervention
        # 2 - no ICN found in MPI: retry 
        # 3 - Station ID returned from MPI is different than preferred location: retry 

        vetext_attributes = {} 

        # preferred facility will either be in eligibility_info, or raw_form_data. If its in neither one,
        # for the purposes of this register method we should not be fetching facilities and trying to reconcile;
        # instead we will set the state to :enrollment_out_of_band

        # Get the preferred facility here as it is needed in MPI lookup 
        facility = eligibility_info['preferred_facility'] || raw_form_data['preferred_facility'].delete_prefix('vha_')
        if facility.blank?
          submission.enrollment_out_of_band!
          return
        end

        vetext_attributes.merge!(form_attributes(raw_form_data, facility))

        # MPI Query must succeed and return ICN and expected facilityID before we send this data to backend service
        mpi_attributes = attributes_from_mpi(raw_form_data, facility) 
        if mpi_attributes[:error].present?
          Rails.logger.info (
            "#{self.class.name}:Error in MPI Lookup",
            mpi_error: mpi_attributes[:error],
            submission: submission.id
          )
          return
        else
          vetext_attributes.merge!(mpi_attributes)
        end

        submit_and_save(vetext_attributes, submission, user_type)
      end

      private

      def submit_and_save(attributes, submission, user_type)
        # TODO: error handling
        audit_log(attributes, user_type)
        response = submit(attributes)
        Rails.logger.info("Covid_Vaccine_Expanded Vetext Response: #{response}")
        submission.update!(sid: response[:sid], form_data: attributes)
        submit_confirmation_email(attributes[:email], submission.created_at, response[:sid])
        submission
      end

      def submit_confirmation_email(email, date, sid)
        return if email.blank?

        formatted_date = date.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
        CovidVaccine::RegistrationEmailJob.perform_async(email, formatted_date, sid)
      end

      def submit(attributes)
        CovidVaccine::V0::VetextService.new.put_vaccine_registry(attributes)
      end

      def audit_log(attributes, user_type)
        log_attrs = {
          auth_type: user_type,
          vaccine_interest: attributes[:vaccine_interest],
          zip_code: attributes[:zip_code],
          has_phone: attributes[:phone].present?,
          has_email: attributes[:email].present?,
          has_dob: attributes[:date_of_birth].present?,
          has_ssn: attributes[:patient_ssn].present?,
          has_icn: attributes[:patient_icn].present?,
          has_facility: attributes[:sta3n].present? || attributes[:sta6a].present?,
          is_expanded_eligibility: true
        }
        Rails.logger.info('Covid_Vaccine Expanded Submission', log_attrs)
      end

      def form_attributes(form_data, facility)
        full_address = [form_data['address_line1'], form_data['address_line2'], form_data['address_line3'].join(' ').strip
        service_date_range = form_data['date_range'] ? form_data['date_range'].to_a.flatten.join(' ') : ''
        {
          vaccine_interest: true,
          address: full_address,
          city: form_data['city'],
          state: form_data['state_code'],
          zip_code: form_data['zip_code'],
          phone: form_data['phone'],
          email: form_data['email'] || '',
          applicant_type: form_data['applicant_type'],
          privacy_agreement_accepted: form_data['privacy_agreement_accepted'],
          sms_acknowledgement: form_data['sms_acknowledgement'] || false,
          birth_sex: form_data['birth_sex'],
          last_branch_of_service: form_data['last_branch_of_service'] || '',
          service_date_range: service_date_range,
          character_of_service: form_data['character_of_service'] || '',
          enhanced_eligibility: true,
          sta3n: facility,
          authenticated: false
        }
      end

      def facility_attributes(form_data)
        @facility_attributes ||= begin
          CovidVaccine::V0::FacilityLookupService.new.facilities_for(form_data['zip_code'])
        rescue => e
          log_exception_to_sentry(e)
          {}
        end
      end

      def attributes_from_mpi(form_data, sta3n)
        ui = OpenStruct.new(first_name: form_data['first_name'],
                            last_name: form_data['last_name'],
                            birth_date: form_data['birth_date'],
                            ssn: form_data['ssn'],
                            gender: form_data['gender'],
                            valid?: true)
        response = MPI::Service.new.find_profile(ui)
        
        if response.status == 'OK'
          if response.profile&.vha_facility_ids.include? sta3n
            {
              first_name: response.profile&.given_names&.first,
              last_name: response.profile&.family_name,
              date_of_birth: response.profile&.birth_date&.to_date&.to_s,
              patient_ssn: response.profile&.ssn,
              patient_icn: response.profile.icn
              # Not currently supported
              # zip: response.profile&.address&.postal_code
          }
          else
            {error: "no matching facility found for #{sta3n}"}
          end
        else 
            {error: 'no ICN found'}
        end
      end
    end
  end
end
