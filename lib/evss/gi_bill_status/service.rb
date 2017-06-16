# frozen_string_literal: true
require 'evss/base_service'

module EVSS
  module GiBillStatus
    class Service < EVSS::BaseService
      BASE_URL = "#{Settings.evss.url}/wss-education-services-web/rest/education/chapter33/v1"

      def get_gi_bill_status
        raw_response = get ''
        puts raw_response.body
        EVSS::GiBillStatus::GiBillStatusResponse.new(raw_response)
      end
    end
  end
end

{ "chapter33_education_info" => { "date_of_birth" => "1955-11-12T06:00:00.000+0000", "enrollments" => [{ "begin_date" => "2012-11-01T04:00:00.000+0000", "end_date" => "2012-12-01T05:00:00.000+0000", "facility_code" => "11902614", "facility_name" => "PURDUE UNIVERSITY", "full_time_hours" => 12, "on_campus_hours" => 12.0, "online_hours" => 0.0, "participant_id" => "11170323", "status" => "Approved", "training_type" => "UNDER_GRAD", "vacation_day_count" => 0, "yellow_ribbon_amount" => 0.0 }], "first_name" => "Srikanth", "last_name" => "Vanapalli", "regional_processing_office" => "Central Office Washington, DC", "va_file_number" => "123456789" } }
