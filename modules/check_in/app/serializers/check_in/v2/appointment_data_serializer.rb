# frozen_string_literal: true

module CheckIn
  module V2
    class AppointmentDataSerializer
      include FastJsonapi::ObjectSerializer

      set_id(&:id)
      set_type :appointment_data

      attribute :payload do |object|
        appointments =
          object.payload[:appointments].map do |appt|
            appt.except!(:patientDFN, :stationNo)
          end

        if Flipper.enabled?(:check_in_experience_demographics_page_enabled)
          raw_demographics = object.payload[:demographics]
          demographics = {
            mailingAddress: address_helper(raw_demographics[:mailingAddress]),
            homeAddress: address_helper(raw_demographics[:homeAddress]),
            homePhone: raw_demographics[:homePhone],
            mobilePhone: raw_demographics[:mobilePhone],
            workPhone: raw_demographics[:workPhone],
            emailAddress: raw_demographics[:emailAddress]
          }

          if Flipper.enabled?(:check_in_experience_next_of_kin_enabled)
            raw_next_of_kin = object.payload.dig(:demographics, :nextOfKin1)
            next_of_kin1 = {
              name: raw_next_of_kin[:name],
              relationship: raw_next_of_kin[:relationship],
              phone: raw_next_of_kin[:phone],
              workPhone: raw_next_of_kin[:workPhone],
              address: address_helper(raw_next_of_kin[:address])
            }
            demographics.merge!(nextOfKin1: next_of_kin1)
          end

          if Flipper.enabled?(:check_in_experience_emergency_contact_enabled)
            raw_emergency_contact = object.payload.dig(:demographics, :emergencyContact)
            emergency_contact = {
              name: raw_emergency_contact[:name],
              relationship: raw_emergency_contact[:relationship],
              phone: raw_emergency_contact[:phone],
              workPhone: raw_emergency_contact[:workPhone],
              address: address_helper(raw_emergency_contact[:address])
            }
            demographics.merge!(emergencyContact: emergency_contact)
          end

          { demographics: demographics, appointments: appointments }
        else
          { appointments: appointments }
        end
      end

      def self.address_helper(address)
        {
          street1: address[:street1],
          street2: address[:street2],
          street3: address[:street3],
          city: address[:city],
          county: address[:county],
          state: address[:state],
          zip: address[:zip],
          zip4: address[:zip4],
          country: address[:country]
        }
      end
    end
  end
end
