# frozen_string_literal: true

module Facilities
  class NCAFacility < BaseFacility
    class << self
      attr_writer :validate_on_load

      def pull_source_data
        metadata = Facilities::Metadata::Client.new.get_metadata(arcgis_type)
        max_record_count = metadata['maxRecordCount']
        Facilities::Client.new.get_all_facilities(arcgis_type, sort_field, max_record_count).map(&method(:new))
      end

      def service_list
        []
      end

      def arcgis_type
        'NCA_Facilities'
      end

      def sort_field
        'SITE_ID'
      end

      def attribute_map
        {
          'unique_id' => 'SITE_ID',
          'name' => 'FULL_NAME',
          'classification' => 'SITE_TYPE',
          'website' => 'Website_URL',
          'phone' => { 'main' => 'PHONE', 'fax' => 'FAX' },
          'physical' => { 'address_1' => 'SITE_ADDRESS1', 'address_2' => 'SITE_ADDRESS2',
                          'address_3' => '', 'city' => 'SITE_CITY', 'state' => 'SITE_STATE',
                          'zip' => 'SITE_ZIP' },
          'mailing' => { 'address_1' => 'MAIL_ADDRESS1', 'address_2' => 'MAIL_ADDRESS2',
                         'address_3' => '', 'city' => 'MAIL_CITY', 'state' => 'MAIL_STATE',
                         'zip' => 'MAIL_ZIP' },
          'hours' => { 'Monday' => 'VISITATION_HOURS_WEEKDAY', 'Tuesday' => 'VISITATION_HOURS_WEEKDAY',
                       'Wednesday' => 'VISITATION_HOURS_WEEKDAY', 'Thursday' => 'VISITATION_HOURS_WEEKDAY',
                       'Friday' => 'VISITATION_HOURS_WEEKDAY', 'Saturday' => 'VISITATION_HOURS_WEEKEND',
                       'Sunday' => 'VISITATION_HOURS_WEEKEND' },
          'mapped_fields' => %w[SITE_ID FULL_NAME SITE_TYPE Website_URL SITE_ADDRESS1 SITE_ADDRESS2 SITE_CITY
                                SITE_STATE SITE_ZIP MAIL_ADDRESS1 MAIL_ADDRESS2 MAIL_CITY MAIL_STATE MAIL_ZIP
                                PHONE FAX VISITATION_HOURS_WEEKDAY VISITATION_HOURS_WEEKEND]

        }
      end
    end
  end
end
