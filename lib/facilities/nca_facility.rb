# frozen_string_literal: true

module Facilities
  class NCAFacility < BaseFacility
    FACILITY_TYPE = 'va_cemetery'
    default_scope { where(facility_type: FACILITY_TYPE) }

    class << self
      def pull_source_data
        sources = Facilities::Client.new.get_all_nca
        sources['features'].map { |entry| new attribute_mappings(entry) }
      end

      def attribute_mappings(entry)
        attrs = entry['attributes']
        {
          unique_id: attrs['SITE_ID'],
          name: attrs['FULL_NAME'],
          classification: attrs['SITE_TYPE'],
          website: attrs['Website_URL'],
          lat: entry['geometry']['x'],
          long: entry['geometry']['y'],
          address: address(attrs),
          phone: {
            'main' => attrs['PHONE'],
            'fax' => attrs['FAX']
          },
          hours: hours(attrs)
        }
      end

      def address(attrs)
        { 'physical' => {
          'address_1' => attrs['SITE_ADDRESS1'],
          'address_2' => attrs['SITE_ADDRESS2'],
          'address_3' => '',
          'city' => attrs['SITE_CITY'],
          'state' => attrs['SITE_STATE'],
          'zip' => attrs['SITE_ZIP']
        },
          'mailing' => {
            'address_1' => attrs['MAIL_ADDRESS1'],
            'address_2' => attrs['MAIL_ADDRESS2'],
            'address_3' => '',
            'city' => attrs['MAIL_CITY'],
            'state' => attrs['MAIL_STATE'],
            'zip' => attrs['MAIL_ZIP']
          } }
      end

      def hours(attrs)
        { 'Monday' => attrs['VISITATION_HOURS_WEEKDAY'],
          'Tuesday' => attrs['VISITATION_HOURS_WEEKDAY'],
          'Wednesday' => attrs['VISITATION_HOURS_WEEKDAY'],
          'Thursday' => attrs['VISITATION_HOURS_WEEKDAY'],
          'Friday' => attrs['VISITATION_HOURS_WEEKDAY'],
          'Saturday' => attrs['VISITATION_HOURS_WEEKEND'],
          'Sunday' => attrs['VISITATION_HOURS_WEEKEND'] }
      end
    end
  end
end
