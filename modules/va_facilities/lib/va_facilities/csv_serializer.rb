# frozen_string_literal: true

require 'csv'
require_dependency 'va_facilities/api_serialization'

module VaFacilities
  class CsvSerializer
    extend ApiSerialization

    def self.to_csv(resource)
      csv_string = CSV.generate(+'', headers: headers, write_headers: true) do |csv|
        resource.each do |object|
          csv << to_row(object)
        end
      end
      csv_string
    end

    def self.headers
      %w[
        id name station_id latitude longitude
        facility_type classification website mobile active_status
        physical_address_1 physical_address_2 physical_address_3
        physical_city physical_state physical_zip
        mailing_address_1 mailing_address_2 mailing_address_3
        mailing_city mailing_state mailing_zip
        phone_main phone_fax phone_mental_health_clinic phone_pharmacy phone_after_hours
        phone_patient_advocate phone_enrollment_coordinator
        hours_monday hours_tuesday hours_wednesday hours_thursday hours_friday
        hours_saturday hours_sunday
      ]
    end

    def self.to_row(object)
      result = [id(object), object.name, object.unique_id, object.lat, object.long,
                object.facility_type, object.classification, object.website, object.mobile, object.active_status]
      result += address_attrs(object)
      result += phone_attrs(object)
      result += hours_attrs(object)
      result
    end

    def self.address_attrs(object)
      physical = object.address['physical']
      mailing = object.address['mailing']
      [physical['address_1'], physical['address_2'], physical['address_3'],
       physical['city'], physical['state'], physical['zip'],
       mailing['address_1'], mailing['address_2'], mailing['address_3'],
       mailing['city'], mailing['state'], mailing['zip']]
    end

    def self.phone_attrs(object)
      phone = object.phone
      [phone['main'], phone['fax'], phone['mental_health_clinic'], phone['pharmacy'], phone['after_hours'],
       phone['patient_advocate'], phone['enrollment_coordinator']]
    end

    def self.hours_attrs(object)
      hours = object.hours
      if object.facility_type_prefix == 'vc'
        %w[monday tuesday wednesday thursday friday saturday sunday].map { |day| hours[day] }
      else
        %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].map { |day| hours[day] }
      end
    end
  end
end
