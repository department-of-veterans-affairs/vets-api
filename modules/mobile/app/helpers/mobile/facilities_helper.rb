# frozen_string_literal: true

module Mobile
  module FacilitiesHelper
    module_function

    def get_facilities(facility_ids)
      facilities_service.get_facilities(ids: facility_ids.to_a.map { |id| "vha_#{id}" }.join(','))
    end

    def get_facility_names(facility_ids)
      facilities = get_facilities(facility_ids)
      facilities.map(&:name)
    end

    def facilities_service
      Lighthouse::Facilities::Client.new
    end

    def address_from_facility(facility)
      if facility.type == 'va_health_facility' # for MFS Facilities
        address = facility.physical_address
        street = address[:line].compact.join(', ')
        zip_code = address[:postal_code]
      else
        address = facility.address['physical']
        street = address.slice('address_1', 'address_2', 'address_3').values.compact.join(', ')
        zip_code = address['zip']
      end
      Mobile::V0::Address.new(
        street: street,
        city: address.symbolize_keys[:city],
        state: address.symbolize_keys[:state],
        zip_code: zip_code
      )
    end

    def blank_location(appointment)
      appointment.location.new(
        name: 'No location provided',
        address: Mobile::V0::Address.new(street: nil, city: nil, state: nil, zip_code: nil),
        phone: nil,
        lat: nil,
        long: nil
      )
    end

    def phone_from_facility(facility)
      phone = facility.phone.symbolize_keys[:main]
      return nil unless phone

      # captures area code (\d{3}) number (\d{3}-\d{4})
      # and optional extension (until the end of the string) (?:\sx(\d*))?$
      phone_captures = phone.match(/^(\d{3})-(\d{3}-\d{4})(?:\sx(\d*))?$/)

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
