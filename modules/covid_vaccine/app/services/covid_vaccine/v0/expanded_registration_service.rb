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

        if raw_form_data['preferred_facility'].empty? 
          facility_data = facility_attributes(raw_form_data);
          if facility_data == {}
          Rails.logger.info ("Covid_Vaccine_Expanded Error when looking up zipcode #{raw_form_data[:zip_code]} in FacilityLookupService. DB record ID: #{submission.id}")
            # Log error and return success to sidekiq so it does not continue to retry
            return
          else
            vetext_attributes.merge!(facility_attributes(raw_form_data))
          end
        end

        # Get the preferred facility here as it is needed in MPI lookup 
        facilityArray = raw_form_data['preferred_facility'].split('_')
        facilitySta3n = facilityArray.length >= 2 ? facilityArray[1] : nil
        
        vetext_attributes = form_attributes(raw_form_data, facilitySta3n)

        # MPI Query must succeed and return ICN and expected facilityID before we send this data to backend service
        mpi_attributes = attributes_from_mpi(raw_form_data, facilitySta3n) 
        if mpi_attributes[:error].present?
          Rails.logger.info ("Covid_Vaccine_Expanded MPI lookup issue: #{mpi_attributes[:error]} - DB record ID: #{submission.id}")
          # Log issue of failed lookup and raise exception so sidekiq keeps retrying
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

      def form_attributes(form_data, facilitySta3n)
        fullAddress = "#{form_data['address_line1']}#{' ' unless form_data['addressLine2'].to_s.empty?}#{form_data['addressLine2']}#{' ' unless form_data['addressLine3'].to_s.empty?}#{form_data['addressLine3']}"
        # facilityArray = form_data['preferred_facility'].split('_')
        # facilitySta3n = facilityArray.length >= 2 ? facilityArray[1] : nil
        serviceDateRange = form_data['date_range'] ? "from #{form_data['date_range']['from']} to #{form_data['date_range']['to']}" : ''
        {
          vaccine_interest: true,
          address: fullAddress,
          city: form_data['city'],
          state: form_data['state_code'],
          zip_code: form_data['zip_code'],
          phone: form_data['phone'],
          email: form_data['email'] ? form_data['email'] : '',
          applicant_type: form_data['applicant_type'],
          privacy_agreement_accepted: form_data['privacy_agreement_accepted'],
          sms_acknowledgement: form_data['sms_acknowledgement'] == true ? true : false,
          birth_sex: form_data['birth_sex'],
          last_branch_of_service: form_data['last_branch_of_service'] ? form_data['last_branch_of_service'] : '',
          service_date_range: serviceDateRange,
          character_of_service: form_data['character_of_service'] ? form_data['character_of_service'] : '',
          enhanced_eligibility: true,
          sta3n: facilitySta3n,
          authenticated: false
        }
      end

      def facility_attributes(form_data)
        svc = CovidVaccine::V0::FacilityLookupService.new
        svc.facilities_for(form_data['zip_code'])
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
