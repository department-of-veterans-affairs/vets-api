# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::VaccinesUpdaterJob, type: :job do
  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  it 'creates records for all vaccines in the group_names xml', :aggregate_failures do
    VCR.use_cassette('vaccines/group_names') do
      VCR.use_cassette('vaccines/manufacturers') do
        service = described_class.new
        expect do
          service.perform
        end.to change { Mobile::V0::Vaccine.count }.from(0).to(3)

        covid_no_manufacturer = Mobile::V0::Vaccine.find_by(cvx_code: 503)
        expect(covid_no_manufacturer.group_name).to eq('COVID-19')
        covid_with_manufacturer = Mobile::V0::Vaccine.find_by(cvx_code: 207)
        expect(covid_with_manufacturer.group_name).to eq('COVID-19')
        non_covid_multiple_groups = Mobile::V0::Vaccine.find_by(cvx_code: 110)
        expect(non_covid_multiple_groups.group_name).to eq('DTAP, HepB')
      end
    end
  end

  it 'only sets manufacturer when group name is COVID-19 and manufacturer is available', :aggregate_failures do
    VCR.use_cassette('vaccines/group_names') do
      VCR.use_cassette('vaccines/manufacturers') do
        service = described_class.new
        service.perform

        covid_no_manufacturer = Mobile::V0::Vaccine.find_by(cvx_code: 503)
        expect(covid_no_manufacturer.manufacturer).to be_nil
        covid_with_manufacturer = Mobile::V0::Vaccine.find_by(cvx_code: 207)
        expect(covid_with_manufacturer.manufacturer).to eq('Moderna US, Inc.')
        non_covid_multiple_groups = Mobile::V0::Vaccine.find_by(cvx_code: 110)
        expect(non_covid_multiple_groups.manufacturer).to be_nil
      end
    end
  end

  context 'when vaccine record exists' do
    let!(:covid_no_manufacturer) { create(:vaccine, cvx_code: 503, group_name: 'FLU', manufacturer: 'Bayer') }
    let!(:covid_with_manufacturer) { create(:vaccine, cvx_code: 207, group_name: 'FLU', manufacturer: 'Bayer') }
    let!(:non_covid_multiple_groups) { create(:vaccine, cvx_code: 110, group_name: 'FLU', manufacturer: 'Bayer') }

    it 'updates the record', :aggregate_failures do
      VCR.use_cassette('vaccines/group_names') do
        VCR.use_cassette('vaccines/manufacturers') do
          service = described_class.new
          service.perform

          expect(covid_no_manufacturer.reload.manufacturer).to be_nil
          expect(covid_no_manufacturer.group_name).to eq('COVID-19')
          expect(covid_with_manufacturer.reload.manufacturer).to eq('Moderna US, Inc.')
          expect(covid_with_manufacturer.group_name).to eq('COVID-19')
          expect(non_covid_multiple_groups.reload.manufacturer).to be_nil
          expect(non_covid_multiple_groups.group_name).to eq('DTAP, HepB')
        end
      end
    end
  end

  context 'when the xml is not structured as expected' do
    it 'raises an error' do
      VCR.use_cassette('vaccines/malformed') do
        service = described_class.new
        expect do
          service.perform
        end.to raise_error(Mobile::V0::VaccinesUpdaterJob::VaccinesUpdaterError, 'Property name CVXCode not found')
      end
    end
  end
end
