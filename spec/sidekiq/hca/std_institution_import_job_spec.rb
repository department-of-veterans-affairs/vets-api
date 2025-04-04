# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe HCA::StdInstitutionImportJob, type: :worker do
  describe '#fetch_csv_data' do
    let(:job) { described_class.new }

    context 'when CSV fetch is successful' do
      it 'returns the CSV data' do
        csv_data = <<~CSV
          header1,header2
          value1,value2
        CSV
        stub_request(:get, 'https://sitewide-public-websites-income-limits-data.s3-us-gov-west-1.amazonaws.com/std_institution.csv')
          .to_return(status: 200, body: csv_data)

        result = job.fetch_csv_data
        expect(result).to eq(csv_data)
      end
    end

    context 'when CSV fetch fails' do
      it 'logs an error and returns nil' do
        stub_request(:get, 'https://sitewide-public-websites-income-limits-data.s3-us-gov-west-1.amazonaws.com/std_institution.csv')
          .to_return(status: 404)

        expect(Rails.logger).to receive(:info).with('CSV retrieval failed with response code 404')
        result = job.fetch_csv_data
        expect(result).to be_nil
      end
    end
  end

  describe '#perform' do
    context 'actual records' do
      it 'populates institutions with the relevant attributes' do
        csv_data = <<~CSV
          ID,ACTIVATIONDATE,DEACTIVATIONDATE,NAME,STATIONNUMBER,VISTANAME,AGENCY_ID,STREETCOUNTRY_ID,STREETADDRESSLINE1,STREETADDRESSLINE2,STREETADDRESSLINE3,STREETCITY,STREETSTATE_ID,STREETCOUNTY_ID,STREETPOSTALCODE,MAILINGCOUNTRY_ID,MAILINGADDRESSLINE1,MAILINGADDRESSLINE2,MAILINGADDRESSLINE3,MAILINGCITY,MAILINGSTATE_ID,MAILINGCOUNTY_ID,MAILINGPOSTALCODE,FACILITYTYPE_ID,MFN_ZEG_RECIPIENT,PARENT_ID,REALIGNEDFROM_ID,REALIGNEDTO_ID,VISN_ID,VERSION,CREATED,UPDATED,CREATEDBY,UPDATEDBY
          1000250,,,AUDIE L. MURPHY MEMORIAL HOSP,671,AUDIE L. MURPHY MEMORIAL HOSP,1009121,1006840,7400 MERTON MINTER BLVD,,,SAN ANTONIO,1009348,,78229-4404,1006840,7400 MERTON MINTER BLVD,,,SAN ANTONIO,1009348,,78229-4404,1009231,1,1002217,,,1002217,0,2004-06-04 13:18:48 +0000,2015-12-28 10:05:46 +0000,Initial Load,DataBroker - CQ# 0938 12/09/2015
          1000090,,1969-12-31 00:00:00 +0000,CRAWFORD COUNTY CBOC (420),420,ZZ CRAWFORD COUNTY CBOC,1009121,1006840,,,,,1009342,,,,,,,,,,,1009197,0,,,,,0,2004-06-04 13:18:48 +0000,2007-05-07 10:18:36 +0000,Initial Load,Cleanup For Inactive Rows
        CSV
        allow_any_instance_of(HCA::StdInstitutionImportJob).to receive(:fetch_csv_data).and_return(csv_data)

        expect do
          described_class.new.perform
        end.to change(StdInstitutionFacility, :count).by(2)

        san_antonio_facility = StdInstitutionFacility.find_by(station_number: '671')
        expect(san_antonio_facility.name).to eq 'AUDIE L. MURPHY MEMORIAL HOSP'
        expect(san_antonio_facility.deactivation_date).to be_nil

        deacrivated_crawford_facility = StdInstitutionFacility.find_by(station_number: '420')
        expect(deacrivated_crawford_facility.name).to eq 'CRAWFORD COUNTY CBOC (420)'
        expect(deacrivated_crawford_facility.deactivation_date).to eq Date.new(1969, 12, 31)
      end
    end

    context 'maximum record' do
      it 'sets the attributes correctly' do
        csv_data = <<~CSV
          ID,ACTIVATIONDATE,DEACTIVATIONDATE,NAME,STATIONNUMBER,VISTANAME,AGENCY_ID,STREETCOUNTRY_ID,STREETADDRESSLINE1,STREETADDRESSLINE2,STREETADDRESSLINE3,STREETCITY,STREETSTATE_ID,STREETCOUNTY_ID,STREETPOSTALCODE,MAILINGCOUNTRY_ID,MAILINGADDRESSLINE1,MAILINGADDRESSLINE2,MAILINGADDRESSLINE3,MAILINGCITY,MAILINGSTATE_ID,MAILINGCOUNTY_ID,MAILINGPOSTALCODE,FACILITYTYPE_ID,MFN_ZEG_RECIPIENT,PARENT_ID,REALIGNEDFROM_ID,REALIGNEDTO_ID,VISN_ID,VERSION,CREATED,UPDATED,CREATEDBY,UPDATEDBY
          1001304,2001-05-21 00:00:00 +0000,2015-06-30 00:00:00 +0000,ZZ-SENECA CLINIC,589GT,ZZ-SENECA CLINIC,1009121,1006840,1600 COMMUNITY DRIVE,,,SENECA,1009320,,66538-9739,1006840,1600 COMMUNITY DRIVE,,,SENECA,1009320,,66538-9739,1009148,0,1001263,1001956,,1002215,0,2004-06-04 13:18:48 +0000,2021-04-12 14:58:11 +0000,Initial Load,DataBroker - CQ# 0998 3/02/2021
        CSV
        allow_any_instance_of(HCA::StdInstitutionImportJob).to receive(:fetch_csv_data).and_return(csv_data)

        described_class.new.perform

        facility = StdInstitutionFacility.find_by(station_number: '589GT')
        expect(facility.id).to eq 1_001_304
        expect(facility.activation_date).to eq Date.new(2001, 5, 21)
        expect(facility.deactivation_date).to eq Date.new(2015, 6, 30)
        expect(facility.name).to eq 'ZZ-SENECA CLINIC'
        expect(facility.station_number).to eq '589GT'
        expect(facility.vista_name).to eq 'ZZ-SENECA CLINIC'
        expect(facility.agency_id).to eq 1_009_121
        expect(facility.street_country_id).to eq 1_006_840
        expect(facility.street_address_line1).to eq '1600 COMMUNITY DRIVE'
        expect(facility.street_address_line2).to be_nil
        expect(facility.street_address_line3).to be_nil
        expect(facility.street_city).to eq 'SENECA'
        expect(facility.street_state_id).to eq 1_009_320
        expect(facility.street_county_id).to be_nil
        expect(facility.street_postal_code).to eq '66538-9739'
        expect(facility.mailing_country_id).to eq 1_006_840
        expect(facility.mailing_address_line1).to eq '1600 COMMUNITY DRIVE'
        expect(facility.mailing_address_line2).to be_nil
        expect(facility.mailing_address_line3).to be_nil
        expect(facility.mailing_city).to eq 'SENECA'
        expect(facility.mailing_state_id).to eq 1_009_320
        expect(facility.mailing_county_id).to be_nil
        expect(facility.mailing_postal_code).to eq '66538-9739'
        expect(facility.facility_type_id).to eq 1_009_148
        expect(facility.mfn_zeg_recipient).to eq 0
        expect(facility.parent_id).to eq 1_001_263
        expect(facility.realigned_from_id).to eq 1_001_956
        expect(facility.realigned_to_id).to be_nil
        expect(facility.visn_id).to eq 1_002_215
        expect(facility.version).to eq 0
        expect(facility.created).to eq '2004-06-04 13:18:48 +0000'
        expect(facility.updated).to eq '2021-04-12 14:58:11 +0000'
        expect(facility.created_by).to eq 'Initial Load'
        expect(facility.updated_by).to eq 'DataBroker - CQ# 0998 3/02/2021'
      end
    end

    context 'when fetch_csv_data returns nil' do
      it 'raises an error' do
        allow_any_instance_of(HCA::StdInstitutionImportJob).to receive(:fetch_csv_data).and_return(nil)

        expect do
          described_class.new.perform
        end.to raise_error(RuntimeError, 'Failed to fetch CSV data.')
      end
    end

    context 'HealthFacilitiesImportJob' do
      let(:csv_data) do
        <<~CSV
          ID,ACTIVATIONDATE,DEACTIVATIONDATE,NAME,STATIONNUMBER,VISTANAME,AGENCY_ID,STREETCOUNTRY_ID,STREETADDRESSLINE1,STREETADDRESSLINE2,STREETADDRESSLINE3,STREETCITY,STREETSTATE_ID,STREETCOUNTY_ID,STREETPOSTALCODE,MAILINGCOUNTRY_ID,MAILINGADDRESSLINE1,MAILINGADDRESSLINE2,MAILINGADDRESSLINE3,MAILINGCITY,MAILINGSTATE_ID,MAILINGCOUNTY_ID,MAILINGPOSTALCODE,FACILITYTYPE_ID,MFN_ZEG_RECIPIENT,PARENT_ID,REALIGNEDFROM_ID,REALIGNEDTO_ID,VISN_ID,VERSION,CREATED,UPDATED,CREATEDBY,UPDATEDBY
          1001304,2001-05-21 00:00:00 +0000,2015-06-30 00:00:00 +0000,ZZ-SENECA CLINIC,589GT,ZZ-SENECA CLINIC,1009121,1006840,1600 COMMUNITY DRIVE,,,SENECA,1009320,,66538-9739,1006840,1600 COMMUNITY DRIVE,,,SENECA,1009320,,66538-9739,1009148,0,1001263,1001956,,1002215,0,2004-06-04 13:18:48 +0000,2021-04-12 14:58:11 +0000,Initial Load,DataBroker - CQ# 0998 3/02/2021
        CSV
      end

      it 'enqueues HCA::HealthFacilitiesImportJob' do
        allow_any_instance_of(HCA::StdInstitutionImportJob).to receive(:fetch_csv_data).and_return(csv_data)

        expect(HCA::HealthFacilitiesImportJob).to receive(:perform_async)

        described_class.new.perform
      end
    end
  end
end
