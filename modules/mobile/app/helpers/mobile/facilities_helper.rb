# frozen_string_literal: true

require 'lighthouse/facilities/client'

module Mobile
  module FacilitiesHelper
    module_function

    def fetch_facilities_from_ids(user, facility_ids, include_children)
      ids = facility_ids.join(',')

      facility_ids.each do |facility_id|
        Rails.logger.info('metric.mobile.appointment.facility', facility_id: facility_id)
      end
      vaos_facilities = VAOS::V2::MobileFacilityService.new(user).get_facilities(ids: ids, children: include_children,
                                                                                 type: nil)
      vaos_facilities[:data]
    end

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

    def user_address_coordinates(user)
      address = user.vet360_contact_info&.residential_address
      unless address&.latitude && address&.longitude
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'User has no home latitude and longitude', source: self.class.to_s
        )
      end

      [address.latitude, address.longitude]
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

    ##
    # Haversine Distance Calculation
    #
    # Accepts two coordinates in the form
    # of a tuple. I.e.
    #   geo_a  Array(Num, Num)
    #   geo_b  Array(Num, Num)
    #   miles  Boolean
    #
    # Returns the distance between these two
    # points in either miles or kilometers
    def haversine_distance(geo_a, geo_b, miles: true)
      Rails.logger.info('haversine_distance coords', geo_a, geo_b)
      # Get latitude and longitude
      lat1, lon1 = geo_a
      lat2, lon2 = geo_b

      # Calculate radial arcs for latitude and longitude
      d_lat = (lat2 - lat1) * Math::PI / 180
      d_lon = (lon2 - lon1) * Math::PI / 180

      a = Math.sin(d_lat / 2) *
          Math.sin(d_lat / 2) +
          Math.cos(lat1 * Math::PI / 180) *
          Math.cos(lat2 * Math::PI / 180) *
          Math.sin(d_lon / 2) * Math.sin(d_lon / 2)

      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      6371 * c * (miles ? 1 / 1.6 : 1)
    end
  end
end
