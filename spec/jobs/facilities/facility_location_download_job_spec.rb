# frozen_string_literal: true

require 'rails_helper'
require 'facilities/bulk_json_client'

RSpec.describe Facilities::FacilityLocationDownloadJob, type: :job do
  before { BaseFacility.validate_on_load = false }

  after { BaseFacility.validate_on_load = true }

  describe 'NCA Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/nca_facilities') do
        expect(Facilities::NCAFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        expect(Facilities::NCAFacility.count).to eq(10)
      end
    end

    it 'does not update data with the same fingerprint' do
      VCR.use_cassette('facilities/va/nca_facilities', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        facility = Facilities::NCAFacility.first
        facility.update(name: 'FIRST')
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        reloaded_facility = Facilities::NCAFacility.find facility.id
        expect(facility.name).to eq(reloaded_facility.name)
      end
    end

    it 'does update data with a changed fingerprint' do
      VCR.use_cassette('facilities/va/nca_facilities', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        facility = Facilities::NCAFacility.first
        facility.update(name: 'FIRST', fingerprint: 'changed')
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        reloaded_facility = Facilities::NCAFacility.find facility.id
        expect(facility.name).not_to eq(reloaded_facility.name)
      end
    end

    it 'adds data that does not exist in the db' do
      VCR.use_cassette('facilities/va/nca_facilities', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        count = Facilities::NCAFacility.count
        Facilities::NCAFacility.all.sample(5).map(&:destroy)
        expect(Facilities::NCAFacility.count).to eq(count - 5)
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        expect(Facilities::NCAFacility.count).to eq(count)
      end
    end

    it 'removes data from the db that does not exist in the source' do
      VCR.use_cassette('facilities/va/nca_facilities', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        count = Facilities::NCAFacility.count
        new_attributes = Facilities::NCAFacility.first.attributes.merge(
          unique_id: 'new_test_facility',
          name: 'new_facility',
          fingerprint: 'new_fingerprint'
        )
        Facilities::NCAFacility.create(new_attributes.except('facility_type'))
        expect(Facilities::NCAFacility.count).to eq(count + 1)
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        expect(Facilities::NCAFacility.count).to eq(count)
      end
    end

    context 'source data returns empty' do
      it 'does not delete cached data' do
        VCR.use_cassette('facilities/va/nca_facilities', allow_playback_repeats: true) do
          Facilities::FacilityLocationDownloadJob.new.perform('nca')
          count = Facilities::NCAFacility.count
          expect(count).not_to eq(0)
          allow(Facilities::NCAFacility).to receive(:pull_source_data).and_return([])
          Facilities::FacilityLocationDownloadJob.new.perform('nca')
          expect(Facilities::NCAFacility.count).to eq(count)
        end
      end
    end

    it 'standardizes closed days to "Closed"' do
      VCR.use_cassette('facilities/va/nca_facilities') do
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        filtered_values = Facilities::NCAFacility.pluck(:hours).map(&:values)
                                                 .flatten.reject { |hours| /am|pm|sunrise|nil/i.match(hours) }
        expect(filtered_values.uniq.length).to be <= 1
        expect(filtered_values.uniq[0]).to eq('Closed') if filtered_values.uniq.length == 1
      end
    end
  end

  describe 'VBA Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
        expect(Facilities::VBAFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('vba')
        expect(Facilities::VBAFacility.count).to eq(6)
      end
    end

    it 'indicates Pensions for appropriate facilities' do
      VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
        expect(Facilities::VBAFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('vba')
        expect(Facilities::VBAFacility.find('310').services['benefits']['standard']).to include('Pensions')
        expect(Facilities::VBAFacility.find('330').services['benefits']['standard']).to include('Pensions')
        expect(Facilities::VBAFacility.find('335').services['benefits']['standard']).to include('Pensions')
        expect(Facilities::VBAFacility.find('0206V').services['benefits']['standard']).not_to include('Pensions')
      end
    end

    it 'adds data that does not exist in the db' do
      VCR.use_cassette('facilities/va/vba_facilities_limit_results', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('vba')
        count = Facilities::VBAFacility.count
        Facilities::VBAFacility.all.sample(5).map(&:destroy)
        expect(Facilities::VBAFacility.count).to eq(count - 5)
        Facilities::FacilityLocationDownloadJob.new.perform('vba')
        expect(Facilities::VBAFacility.count).to eq(count)
      end
    end

    it 'standardizes closed days to "Closed"' do
      VCR.use_cassette('facilities/va/vba_facilities') do
        Facilities::FacilityLocationDownloadJob.new.perform('vba')
        filtered_values = Facilities::VBAFacility.pluck(:hours).map(&:values).flatten
                                                 .reject { |hours| /am|pm|only|call|itinerant/i.match(hours) }
        expect(filtered_values.uniq.length).to be <= 1
        expect(filtered_values.uniq[0]).to eq('Closed') if filtered_values.uniq.length == 1
      end
    end
  end

  describe 'VC Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/vc_facilities') do
        expect(Facilities::VCFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('vc')
        expect(Facilities::VCFacility.count).to eq(10)
      end
    end

    it 'adds data that does not exist in the db' do
      VCR.use_cassette('facilities/va/vc_facilities', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('vc')
        count = Facilities::VCFacility.count
        Facilities::VCFacility.all.sample(5).map(&:destroy)
        expect(Facilities::VCFacility.count).to eq(count - 5)
        Facilities::FacilityLocationDownloadJob.new.perform('vc')
        expect(Facilities::VCFacility.count).to eq(count)
      end
    end

    it 'standardizes closed days to "Closed"' do
      VCR.use_cassette('facilities/va/vc_facilities') do
        Facilities::FacilityLocationDownloadJob.new.perform('vc')
        filtered_values = Facilities::VCFacility.pluck(:hours)
                                                .map(&:values)
                                                .flatten
                                                .reject { |hours| /am|pm/i.match(hours) }
        expect(filtered_values.uniq.length).to be <= 1
        expect(filtered_values.uniq[0]).to eq('Closed') if filtered_values.uniq.length == 1
      end
    end
  end

  describe 'VHA Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
        expect(Facilities::VHAFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('vha')
        expect(Facilities::VHAFacility.count).to eq(3)
      end
    end

    it 'adds data that does not exist in the db' do
      VCR.use_cassette('facilities/va/vha_facilities_limit_results', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('vha')
        count = Facilities::VHAFacility.count
        Facilities::VHAFacility.all.sample(2).map(&:destroy)
        expect(Facilities::VHAFacility.count).to eq(count - 2)
        Facilities::FacilityLocationDownloadJob.new.perform('vha')
        expect(Facilities::VHAFacility.count).to eq(count)
      end
    end
  end

  context 'with facility validation' do
    before { BaseFacility.validate_on_load = true }

    after { BaseFacility.validate_on_load = false }

    it 'raises an error when trying to retrieve and persist facilities data' do
      VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
        expect { Facilities::FacilityLocationDownloadJob.new.perform('vha') }
          .to raise_error(Common::Client::Errors::ParsingError, 'invalid source data: duplicate ids')
      end
    end
  end

  context 'with wait time data' do
    let(:satisfaction_data) do
      fixture_file_name = "#{::Rails.root}/spec/fixtures/facility_access/satisfaction_data.json"
      File.open(fixture_file_name, 'rb') do |f|
        JSON.parse(f.read)
      end
    end

    let(:wait_time_data) do
      fixture_file_name = "#{::Rails.root}/spec/fixtures/facility_access/wait_time_data.json"
      File.open(fixture_file_name, 'rb') do |f|
        JSON.parse(f.read)
      end
    end

    let(:sat_client_stub) { instance_double('Facilities::AccessSatisfactionClient') }
    let(:wait_client_stub) { instance_double('Facilities::AccessWaitTimeClient') }

    before do
      allow(Facilities::AccessSatisfactionClient).to receive(:new) { sat_client_stub }
      allow(Facilities::AccessWaitTimeClient).to receive(:new) { wait_client_stub }
      allow(sat_client_stub).to receive(:download).and_return(satisfaction_data)
      allow(wait_client_stub).to receive(:download).and_return(wait_time_data)
      Facilities::AccessDataDownload.new.perform
    end

    it 'has the wait time indicated services' do
      VCR.use_cassette('facilities/va/vha_facilities') do
        Facilities::FacilityLocationDownloadJob.new.perform('vha')
        facility = Facilities::VHAFacility.find('603')
        services = facility.services['health'].map { |service| service['sl1'].first }
        expected_services = %w[WomensHealth Audiology Cardiology Dermatology Gastroenterology
                               Gynecology Ophthalmology Optometry Orthopedics Urology]
        expect(services).to include(*expected_services)
      end
    end

    it 'standardizes closed days to "Closed"' do
      VCR.use_cassette('facilities/va/vha_facilities') do
        Facilities::FacilityLocationDownloadJob.new.perform('vha')
        filtered_values = Facilities::VHAFacility.pluck(:hours)
                                                 .map(&:values)
                                                 .flatten
                                                 .reject { |hours| %r{am|pm|24/7}i.match(hours) }
        expect(filtered_values.uniq.length).to be <= 1
        expect(filtered_values.uniq[0]).to eq('Closed') if filtered_values.uniq.length == 1
      end
    end
  end
end
