# frozen_string_literal: false
FactoryBot.define do
  factory :nca_gis_record_v1, class: Hash do
    gis_attrs do
      {
        'OBJECTID' => 81,
        'FULL_NAME' => 'Fort Snelling National Cemetery',
        'SHORT_NAME' => 'Ft. Snelling',
        'MAIL_CITY' => 'Minneapolis',
        'MAIL_STATE' => 'MN',
        'MAIL_ZIP' => '55450-1199',
        'PHONE' => '612-726-1127',
        'FAX' => '612-725-2059',
        'DISTRICT' => 'Midwest District',
        'CEMETERY_A' => '7601 34th Ave S',
        'CEMETERY_1' => ' ',
        'CEMETERY_Z' => '55450-1199',
        'MAIL_ADDRE' => '7601 34th Ave S',
        'MAIL_ADD_1' => ' ',
        'GOVERNING_' => 0,
        'CEMETERY_C' => 'Minneapolis',
        'CEMETERY_I' => '894',
        'CEMETERY_S' => 'MN',
        'STATUS' => 'Open',
        'CEM_TYPE' => 'National Cemetery',
        'Sunday' => '8:00am - 5:00pm',
        'Monday' => '7:30am - 5:00pm',
        'Tuesday' => '7:30am - 5:00pm',
        'Wednesday' => '7:30am - 5:00pm',
        'Thursday' => '7:30am - 5:00pm',
        'Friday' => '7:30am - 5:00pm',
        'Saturday' => '8:00am - 5:00pm',
        'Website_URL' => 'http://www.cem.va.gov/cems/nchp/ftsnelling.asp'
      }
    end
    geometry do
      {
        'x' => -93.222882218996432,
        'y' => 44.864600563324544
      }
    end
    initialize_with { { 'attributes' => gis_attrs, 'geometry' => geometry } }
  end

  factory :nca_gis_record_v2, class: Hash do
    gis_attrs do
      {
        'OBJECTID' => 62,
        'SITE_ID' => '894',
        'FULL_NAME' => 'Fort Snelling National Cemetery',
        'SHORT_NAME' => 'Ft. Snelling',
        'SITE_TYPE' => 'National Cemetery',
        'SITE_STATUS' => 'Open',
        'SITE_OWNER' => 'NCA',
        'SITE_ADDRESS1' => '7601 34th Ave S',
        'SITE_ADDRESS2' => nil,
        'SITE_CITY' => 'Minneapolis',
        'SITE_STATE' => 'MN',
        'SITE_ZIP' => '55450-1199',
        'SITE_COUNTRY' => 'USA',
        'MAIL_ADDRESS1' => '7601 34th Ave S',
        'MAIL_ADDRESS2' => nil,
        'MAIL_CITY' => 'Minneapolis',
        'MAIL_STATE' => 'MN',
        'MAIL_ZIP' => '55450-1199',
        'MAIL_COUNTRY' => 'USA',
        'PHONE' => '612-726-1127',
        'FAX' => '612-725-2059',
        'VISITATION_HOURS_WEEKDAY' => '7:30am - 5:00pm',
        'VISITATION_HOURS_WEEKEND' => '8:00am - 5:00pm',
        'VISITATION_HOURS_COMMENT' => nil,
        'OFFICE_HOURS_WEEKDAY' => nil,
        'OFFICE_HOURS_WEEKEND' => nil,
        'OFFICE_HOURS_COMMENT' => nil,
        'SITE_SQFT' => nil,
        'GOVERNING_SITE_ID' => nil,
        'DISTRICT' => 'MSN4',
        'LATITUDE_DD' => 44.86460056,
        'LONGITUDE_DD' => -93.22288222,
        'POSITION_SRC' => 'Imagery',
        'COMMENT' => nil,
        'ACTIVE' => 1,
        'GlobalID' => '{641E4D47-ABE1-4E80-A7D0-3173D235DDD4}',
        'created_user' => 'CEMTHOMARC0',
        'created_date' => 1_487_694_221_000,
        'last_edited_user' => 'SDE',
        'last_edited_date' => 1_492_421_181_000,
        'Website_URL' => 'http://www.cem.va.gov/cems/nchp/ftsnelling.asp'
      }
    end
    geometry do
      {
        'x' => -93.222882218996432,
        'y' => 44.864600563324544
      }
    end
    initialize_with { { 'attributes' => gis_attrs, 'geometry' => geometry } }
  end
end
