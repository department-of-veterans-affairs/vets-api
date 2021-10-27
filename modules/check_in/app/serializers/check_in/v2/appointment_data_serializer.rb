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
            mailingAddress: {
              street1: raw_demographics.dig(:mailingAddress, :street1),
              street2: raw_demographics.dig(:mailingAddress, :street2),
              street3: raw_demographics.dig(:mailingAddress, :street3),
              city: raw_demographics.dig(:mailingAddress, :city),
              county: raw_demographics.dig(:mailingAddress, :county),
              state: raw_demographics.dig(:mailingAddress, :state),
              zip: raw_demographics.dig(:mailingAddress, :zip),
              country: raw_demographics.dig(:mailingAddress, :country)
            },
            homeAddress: {
              street1: raw_demographics.dig(:homeAddress, :street1),
              street2: raw_demographics.dig(:homeAddress, :street2),
              street3: raw_demographics.dig(:homeAddress, :street3),
              city: raw_demographics.dig(:homeAddress, :city),
              county: raw_demographics.dig(:homeAddress, :county),
              state: raw_demographics.dig(:homeAddress, :state),
              zip: raw_demographics.dig(:homeAddress, :zip),
              country: raw_demographics.dig(:homeAddress, :country)
            },
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
              address: {
                street1: raw_next_of_kin.dig(:address, :street1),
                street2: raw_next_of_kin.dig(:address, :street2),
                street3: raw_next_of_kin.dig(:address, :street3),
                city: raw_next_of_kin.dig(:address, :city),
                county: raw_next_of_kin.dig(:address, :county),
                state: raw_next_of_kin.dig(:address, :state),
                zip: raw_next_of_kin.dig(:address, :zip),
                zip4: raw_next_of_kin.dig(:address, :zip4),
                country: raw_next_of_kin.dig(:address, :country)
              }
            }
            demographics.merge!(nextOfKin1: next_of_kin1)
          end

          { demographics: demographics, appointments: appointments }
        else
          { appointments: appointments }
        end
      end
    end
  end
end
