# frozen_string_literal: true

require 'csv'
require 'net/http'

module HCA
  class StdInstitutionImportJob
    include Sidekiq::Job

    STRING_ATTRIBUTES = {
      activation_date: 'ACTIVATIONDATE',
      deactivation_date: 'DEACTIVATIONDATE',
      name: 'NAME',
      station_number: 'STATIONNUMBER',
      vista_name: 'VISTANAME',
      street_address_line1: 'STREETADDRESSLINE1',
      street_address_line2: 'STREETADDRESSLINE2',
      street_address_line3: 'STREETADDRESSLINE3',
      street_city: 'STREETCITY',
      street_postal_code: 'STREETPOSTALCODE',
      mailing_address_line1: 'MAILINGADDRESSLINE1',
      mailing_address_line2: 'MAILINGADDRESSLINE2',
      mailing_address_line3: 'MAILINGADDRESSLINE3',
      mailing_city: 'MAILINGCITY',
      mailing_postal_code: 'MAILINGPOSTALCODE',
      created_by: 'CREATEDBY',
      updated_by: 'UPDATEDBY'
    }.freeze

    INTEGER_ATTRIBUTES = {
      agency_id: 'AGENCY_ID',
      street_country_id: 'STREETCOUNTRY_ID',
      street_state_id: 'STREETSTATE_ID',
      street_county_id: 'STREETCOUNTY_ID',
      mailing_country_id: 'MAILINGCOUNTRY_ID',
      mailing_state_id: 'MAILINGSTATE_ID',
      mailing_county_id: 'MAILINGCOUNTY_ID',
      facility_type_id: 'FACILITYTYPE_ID',
      mfn_zeg_recipient: 'MFN_ZEG_RECIPIENT',
      parent_id: 'PARENT_ID',
      realigned_from_id: 'REALIGNEDFROM_ID',
      realigned_to_id: 'REALIGNEDTO_ID',
      visn_id: 'VISN_ID',
      version: 'VERSION'
    }.freeze

    def fetch_csv_data
      csv_url = 'https://sitewide-public-websites-income-limits-data.s3-us-gov-west-1.amazonaws.com/std_institution.csv'
      uri = URI(csv_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      response_code = response.code
      if response_code == '200'
        response.body
      else
        Rails.logger.info("CSV retrieval failed with response code #{response_code}")

        nil
      end
    end

    def perform
      Rails.logger.info("Job started with #{StdInstitutionFacility.count} existing facilities.")

      ActiveRecord::Base.transaction do
        data = fetch_csv_data
        raise 'Failed to fetch CSV data.' unless data

        import_institutions_from_csv(data)

        HCA::HealthFacilitiesImportJob.perform_async
        Rails.logger.info("Job ended with #{StdInstitutionFacility.count} existing facilities.")
      end
      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.ves_facilities_import_complete")
    end

    private

    def import_institutions_from_csv(data)
      CSV.parse(data, headers: true) do |row|
        id = row['ID'].to_i
        std_institution_facility = StdInstitutionFacility.find_or_initialize_by(id:)
        Rails.logger.info("institution #{id} new? #{std_institution_facility.new_record?}")

        created = DateTime.strptime(row['CREATED'], '%F %H:%M:%S %z').to_s
        updated = DateTime.strptime(row['UPDATED'], '%F %H:%M:%S %z').to_s if row['UPDATED']
        string_attributes = STRING_ATTRIBUTES.transform_values { |string_field| row[string_field]&.to_s }
        integer_attributes = INTEGER_ATTRIBUTES.transform_values { |integer_field| row[integer_field]&.to_i }
        std_institution_facility.assign_attributes(
          { created:, updated: }.merge(string_attributes).merge(integer_attributes)
        )

        std_institution_facility.save!
      end
    end
  end
end
