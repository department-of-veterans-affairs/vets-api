# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationService
      REQUIRED_QUERY_TRAITS = %w[first_name last_name birth_date ssn].freeze

      def register(submission, user_type)
        raw_form_data = submission.raw_form_data
        vetext_attributes = form_attributes(raw_form_data)
        vetext_attributes.merge!(attributes_from_mpi(raw_form_data)) if should_query_mpi?(raw_form_data, user_type)
        vetext_attributes.merge!(facility_attributes(raw_form_data))
        vetext_attributes.merge!({ authenticated: (user_type == 'loa3') }).compact!
        submit_and_save(vetext_attributes, submission, user_type)
      end

      private

      def submit_and_save(attributes, submission, user_type)
        # TODO: error handling
        audit_log(attributes, user_type)
        response = submit(attributes)
        Rails.logger.info("Covid_Vaccine Vetext Response: #{response}")
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
          has_facility: attributes[:sta3n].present? || attributes[:sta6a].present?
        }
        Rails.logger.info('Covid_Vaccine Submission', log_attrs)
      end

      def form_attributes(form_data)
        {
          vaccine_interest: form_data['vaccine_interest'],
          zip_code: form_data['zip_code'],
          time_at_zip: form_data['zip_code_details'],
          phone: form_data['phone'],
          email: form_data['email'],
          # Values below this point will get merged over by values
          # from authenticated user object or MPI if available
          first_name: form_data['first_name'],
          last_name: form_data['last_name'],
          date_of_birth: form_data['birth_date'],
          patient_ssn: form_data['ssn'],
          # This value was only injected from controller if
          # user was authenticated at LOA3
          patient_icn: form_data['icn']
        }
      end

      def facility_attributes(form_data)
        svc = CovidVaccine::V0::FacilityLookupService.new
        svc.facilities_for(form_data['zip_code'])
      end

      def attributes_from_mpi(form_data)
        ui = OpenStruct.new(first_name: form_data['first_name'],
                            last_name: form_data['last_name'],
                            birth_date: form_data['birth_date'],
                            ssn: form_data['ssn'],
                            gender: form_data['gender'],
                            valid?: true)
        response = MPI::Service.new.find_profile(ui)
        if response.status == 'OK'
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
          {}
        end
      end

      ## Guard around MPI query
      # 1. If user_type == loa3, we already have their information from MPI in the
      # authenticated session
      # 2. If not all of the required MPI query keys are present, we can't query MPI
      # 3. If a partial, unparseable date of birth was submitted, we can't query MPI
      #
      def should_query_mpi?(form_data, user_type)
        return false if user_type == 'loa3'
        return false unless (REQUIRED_QUERY_TRAITS & form_data.keys).size == REQUIRED_QUERY_TRAITS.size

        begin
          Date.parse(form_data['birth_date'])
        rescue ArgumentError
          return false
        end
        true
      end
    end
  end
end
