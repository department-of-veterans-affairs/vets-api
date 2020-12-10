# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationService
      REQUIRED_QUERY_TRAITS = %w[first_name last_name birth_date ssn].freeze

      def register(form_data, account_id = nil)
        attributes = form_attributes(form_data)
        attributes.merge!(attributes_from_mpi(form_data))
        attributes.merge!({ authenticated: false }).compact!
        Rails.logger.info("Vetext Payload: #{attributes.to_json}")
        submit(attributes, account_id)
      end

      def register_loa3_user(form_data, user)
        attributes = form_attributes(form_data)
        attributes.merge!(attributes_from_user(user))
        attributes.merge!({ authenticated: true }).compact!
        Rails.logger.info("Vetext Payload: #{attributes.to_json}")
        submit(attributes, user.account_uuid)
      end

      private

      def submit(attributes, account_id)
        # TODO: error handling
        response = CovidVaccine::V0::VetextService.new.put_vaccine_registry(attributes)
        Rails.logger.info("Vetext Response: #{response}")
        CovidVaccine::V0::RegistrationSubmission.create({ sid: response[:sid],
                                                          account_id: account_id,
                                                          form_data: attributes })
      end

      def form_attributes(form_data)
        {
          vaccine_interest: form_data['vaccine_interest'],
          date_vaccine_received: form_data['date_vaccine_received'],
          reason_undecided: form_data['reason_undecided'],
          contact: form_data['contact_preference'],
          contact_method: form_data['contact_method'],
          phone: form_data['phone'],
          email: form_data['email'],
          # Values below this point will get merged over by values
          # from authenticated user object or MPI if available
          first_name: form_data['first_name'],
          last_name: form_data['last_name'],
          date_of_birth: form_data['birth_date'],
          patient_ssn: form_data['ssn']
        }.merge(facility_attrs(form_data))
      end

      def facility_attrs(form_data)
        {
          # TODO: verify this v questionable logic
          sta6a: form_data['preferred_facility']&.delete_prefix('vha_'),
          sta3n: form_data['preferred_facility']&.delete_prefix('vha_')&.slice(0, 3)
        }
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
        return {} unless query_traits_present(form_data)

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
        # TODO: add statsd metrics around MPI queries for both success and fail cases
      end

      def query_traits_present(form_data)
        (REQUIRED_QUERY_TRAITS & form_data.keys).size == REQUIRED_QUERY_TRAITS.size
      end
    end
  end
end
