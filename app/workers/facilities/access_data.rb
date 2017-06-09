# frozen_string_literal: true
require 'facilities/bulk_json_client'
require 'common/exceptions'
require 'facility_access'

module Facilities
  class AccessDataDownload
    include Sidekiq::Worker

    SAT_KEY_MAP = {
      'Primary Care (Routine)' => 'primary_care_routine',
      'Primary Care (Urgent)' => 'primary_care_urgent',
      'Specialty Care (Routine)' => 'specialty_care_routine',
      'Specialty Care (Urgent)' => 'specialty_care_urgent',
    }

    def parse_satisfaction_data(records)
      facilities = Hash.new { |h,k| h[k] = {'metrics' => {}} }
      records.each do |rec|
        id = rec['facilityID']
        facility = facilities[id]
        category = SAT_KEY_MAP[rec['ApptTypeName']]
        facility['metrics'][category] = rec['SHEPScore']
        facility['source_date'] = rec['sliceEndDate']
      end
      facilities
    end

    def update_satisfaction_cache(facilities)
      facilities.each do |k,v|
        attrs = {station_number: k,
                 metrics: v['metrics'],
                 source_updated: v['source_date'],
                 local_updated: Time.now.utc.iso8601}
        obj = FacilitySatisfaction.find(k)
        if obj 
          obj.update(attrs)
        else
          FacilitySatisfaction.create(attrs)
        end
      end
    end

    def update_satisfaction_data(client)
      begin
        records = client.download
        facilities = parse_satisfaction_data(records)
        update_satisfaction_cache(facilities)
      rescue Common::Exceptions::BackendServiceException => e
        # TODO handle
      end
    end

    WT_KEY_MAP = {
      'PRIMARY CARE' => 'primary_care',
      'MENTAL HEALTH' => 'mental_health',
      'WOMEN\'S HEALTH' => 'womens_health',
      'AUDIOLOGY' => 'audiology',
      'CARDIOLOGY' => 'cardiology',
      'GASTROENTEROLOGY' => 'gastroenterology',
      'OPHTHALMOLOGY' => 'opthalmology',
      'OPTOMETRY' => 'optometry',
      'UROLOGY CLINIC' => 'urology_clinic'
    }

    def filter(val)
      val >= 9999 ? nil : val
    end
 
    def parse_wait_time_data(records)
      facilities = Hash.new { |h,k| h[k] = {'metrics' => {}} }
      records.each do |rec|
        id = rec['facilityID']
        facility = facilities[id]
        category = WT_KEY_MAP[rec['ApptTypeName']]
        metric = {'new' => filter(rec['newWaitTime']), 
                  'established' => filter(rec['estWaitTime'])}
        facility['metrics'][category] = metric
        facility['source_date'] = rec['sliceEndDate']
      end
      facilities
    end

    def update_wait_time_cache(facilities)
      facilities.each do |k,v|
        attrs = {station_number: k,
                 metrics: v['metrics'],
                 source_updated: v['source_date'],
                 local_updated: Time.now.utc.iso8601}
        obj = FacilityWaitTime.find(k)
        if obj 
          obj.update(attrs)
        else
          FacilityWaitTime.create(attrs)
        end
      end
    end

    def update_wait_time_data(client)
      begin
        records = client.download
        facilities = parse_wait_time_data(records)
        update_wait_time_cache(facilities)
      rescue Common::Exceptions::BackendServiceException => e
        # TODO handle
      end
    end

    def perform
      sat_client = Facilities::AccessSatisfactionClient.new
      update_satisfaction_data(sat_client)

      pwt_client = Facilities::AccessWaitTimeClient.new
      update_wait_time_data(pwt_client)
    end
  end
end
