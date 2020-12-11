# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationService
      REQUIRED_QUERY_TRAITS = %w[first_name last_name birth_date ssn].freeze

      def register(form_data, account_id = nil)
        attributes = form_attributes(form_data)
        attributes.merge!(attributes_from_mpi(form_data)) if query_traits_present(form_data)
        attributes.merge!(facility_attributes(form_data))
        attributes.merge!({ authenticated: false }).compact!
        user_type = account_id.present? ? 'loa1' : 'unauthenticated'
        submit_and_save(attributes, account_id, user_type)
      end

      def register_loa3_user(form_data, user)
        attributes = form_attributes(form_data)
        attributes.merge!(attributes_from_user(user))
        attributes.merge!(facility_attributes(form_data))
        attributes.merge!({ authenticated: true }).compact!
        submit_and_save(attributes, user.account_uuid, 'loa3')
      end

      private

      def submit_and_save(attributes, account_id, user_type = '')
        # TODO: error handling
        audit_log(attributes, user_type)
        response = submit(attributes)
        Rails.logger.info("Covid_Vaccine Vetext Response: #{response}")
        record = CovidVaccine::V0::RegistrationSubmission.create({ sid: response[:sid],
                                                                   account_id: account_id,
                                                                   form_data: attributes })
        submit_confirmation_email(attributes[:email], record.created_at, response[:sid])
        record
      end

      def submit_confirmation_email(email, date, sid)
        return if email.empty?

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
          patient_ssn: form_data['ssn']
        }
      end

      def facility_attributes(form_data)
        svc = CovidVaccine::V0::FacilityLookupService.new
        svc.facilities_for(form_data['zip_code'])
      end

      def attributes_from_user(user)
        return {} unless user.loa3?

        {
          first_name: user.first_name,
          last_name: user.last_name,
          date_of_birth: user.birth_date,
          patient_ssn: user.ssn,
          patient_icn: user.icn
          # Not currently supported
          # zip: user.zip
        }
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

      def query_traits_present(form_data)
        (REQUIRED_QUERY_TRAITS & form_data.keys).size == REQUIRED_QUERY_TRAITS.size
      end
    end
  end
end
