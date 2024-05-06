# frozen_string_literal: true

module CheckIn
  module V2
    class AppointmentDataSerializer
      include JSONAPI::Serializer

      set_id(&:id)
      set_type :appointment_data

      attribute :payload do |object|
        appointments =
          object.payload[:appointments].map do |appt|
            appt.except!(:patientDFN, :icn, :edipi)
          end

        demographics = prepare_demographics(object.payload[:demographics])

        raw_confirmation = object.payload[:patientDemographicsStatus]
        demographics_confirmation = if raw_confirmation.nil?
                                      {}
                                    else
                                      {
                                        demographicsNeedsUpdate: raw_confirmation[:demographicsNeedsUpdate],
                                        demographicsConfirmedAt: raw_confirmation[:demographicsConfirmedAt],
                                        nextOfKinNeedsUpdate: raw_confirmation[:nextOfKinNeedsUpdate],
                                        nextOfKinConfirmedAt: raw_confirmation[:nextOfKinConfirmedAt],
                                        emergencyContactNeedsUpdate: raw_confirmation[:emergencyContactNeedsUpdate],
                                        emergencyContactConfirmedAt: raw_confirmation[:emergencyContactConfirmedAt]
                                      }
                                    end

        {
          address: object.payload[:address],
          demographics:,
          appointments:,
          patientDemographicsStatus: demographics_confirmation,
          setECheckinStartedCalled: object.payload[:setECheckinStartedCalled]
        }
      end

      def self.prepare_demographics(raw_demographics)
        return {} if raw_demographics.nil?

        demographics = {
          mailingAddress: address_helper(raw_demographics[:mailingAddress]),
          homeAddress: address_helper(raw_demographics[:homeAddress]),
          homePhone: raw_demographics[:homePhone],
          mobilePhone: raw_demographics[:mobilePhone],
          workPhone: raw_demographics[:workPhone],
          emailAddress: raw_demographics[:emailAddress]
        }

        demographics.merge!(nextOfKin1: prepare_contact(raw_demographics[:nextOfKin1])) if raw_demographics[:nextOfKin1]
        if raw_demographics[:emergencyContact]
          demographics.merge!(emergencyContact: prepare_contact(raw_demographics[:emergencyContact]))
        end

        demographics
      end

      def self.prepare_contact(raw_contact)
        {
          name: raw_contact[:name],
          relationship: raw_contact[:relationship],
          phone: raw_contact[:phone],
          workPhone: raw_contact[:workPhone],
          address: address_helper(raw_contact[:address])
        }
      end

      def self.address_helper(address)
        return {} if address.nil?

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
