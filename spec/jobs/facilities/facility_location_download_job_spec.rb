# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::FacilityLocationDownloadJob, type: :job do
  describe 'NCA Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/nca_facilities') do
        expect(Facilities::NCAFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        expect(Facilities::NCAFacility.count).to eq(173)
      end
    end

    it 'does not update data with the same fingerprint' do
      VCR.use_cassette('facilities/va/nca_facilities', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        facility = Facilities::NCAFacility.first
        facility.update_attributes(name: 'FIRST')
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        reloaded_facility = Facilities::NCAFacility.find facility.id
        expect(facility.name).to eq(reloaded_facility.name)
      end
    end

    it 'does update data with a changed fingerprint' do
      VCR.use_cassette('facilities/va/nca_facilities', allow_playback_repeats: true) do
        Facilities::FacilityLocationDownloadJob.new.perform('nca')
        facility = Facilities::NCAFacility.first
        facility.update_attributes(name: 'FIRST', fingerprint: 'changed')
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
  end

  describe 'VBA Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/vba_facilities') do
        expect(Facilities::VBAFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('vba')
        expect(Facilities::VBAFacility.count).to eq(487)
      end
    end
  end

  describe 'VC Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/vc_facilities') do
        expect(Facilities::VCFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('vc')
        expect(Facilities::VCFacility.count).to eq(318)
      end
    end
  end

  describe 'VHA Facilities' do
    it 'retrieves and persists facilities data' do
      VCR.use_cassette('facilities/va/vha_facilities') do
        expect(Facilities::VHAFacility.count).to eq(0)
        Facilities::FacilityLocationDownloadJob.new.perform('vha')
        expect(Facilities::VHAFacility.count).to eq(1185)
      end
    end
  end
end
