# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class VAFacilities
        def map_appointments_to_facilities(appointments, facilities)
          facilities_by_id = facilities.index_by(&:id)

          appointments.map do |appointment|
            facility = facilities_by_id["vha_#{appointment.id_for_address}"]
            # resources are immutable and are updated with new copies
            appointment.new(
              location: appointment.location.new(
                name: facility['name'],
                address: address_from_facility(facility),
                phone: phone_from_facility(facility),
                lat: facility.lat,
                long: facility.long
              )
            )
          end
        end

        def address_from_facility(facility)
          address = facility.address['physical']
          return nil unless address

          Mobile::V0::AppointmentAddress.new(
            street: address.slice('address_1', 'address_2', 'address_3').values.compact.join(', '),
            city: address['city'],
            state: address['state'],
            zip_code: address['zip']
          )
        end

        def phone_from_facility(facility)
          phone = facility.phone['main']
          return nil unless phone

          # captures area code (\d{3}) number (\d{3}-\d{4})
          # and optional extension (until the end of the string) (?:\sx(\d*))?$
          phone_captures = facility.phone['main'].match(/^(\d{3})-(\d{3}-\d{4})(?:\sx(\d*))?$/)

          if phone_captures.nil?
            Rails.logger.warn(
              'mobile appointments failed to parse facility phone number',
              facility_id: facility.id,
              facility_phone: facility.phone
            )
            return nil
          end

          Mobile::V0::AppointmentPhone.new(
            area_code: phone_captures[1].presence,
            number: phone_captures[2].presence,
            extension: phone_captures[3].presence
          )
        end
      end
    end
  end
end
