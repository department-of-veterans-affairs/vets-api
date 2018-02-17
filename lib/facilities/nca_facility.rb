# frozen_string_literal: true

module Facilities
  class NCAFacility < BaseFacility
    FACILITY_TYPE = 'va_cemetery'
    default_scope { where(facility_type: FACILITY_TYPE) }

    class << self
      def pull_source_data
        sources = Facilities::Client.new.get_all_nca
        sources[:features].map { |entry| new attribute_mappings(entry) }
      end

      def attribute_mappings(entry)
        attrs = entry[:attributes]
        {
          unique_id: attrs[:site_id],
          name: attrs[:full_name],
          classification: attrs[:site_type],
          website: attrs[:website_url],
          lat: entry[:geometry][:x],
          long: entry[:geometry][:y],
          address: address(attrs),
          phone: phone(attrs),
          hours: hours(attrs)
        }
      end

      def phone(attrs)
        { 'main' => attrs[:phone],
          'fax' => attrs[:fax] }
      end

      def address(attrs)
        { 'physical' => {
          'address_1' => attrs[:site_address1],
          'address_2' => attrs[:site_address2],
          'address_3' => '',
          'city' => attrs[:site_city],
          'state' => attrs[:site_state],
          'zip' => attrs[:site_zip]
        },
          'mailing' => {
            'address_1' => attrs[:mail_address1],
            'address_2' => attrs[:mail_address2],
            'address_3' => '',
            'city' => attrs[:mail_city],
            'state' => attrs[:mail_state],
            'zip' => attrs[:mail_zip]
          } }
      end

      def hours(attrs)
        { 'Monday' => attrs[:visitation_hours_weekday],
          'Tuesday' => attrs[:visitation_hours_weekday],
          'Wednesday' => attrs[:visitation_hours_weekday],
          'Thursday' => attrs[:visitation_hours_weekday],
          'Friday' => attrs[:visitation_hours_weekday],
          'Saturday' => attrs[:visitation_hours_weekend],
          'Sunday' => attrs[:visitation_hours_weekend] }
      end
    end
  end
end
