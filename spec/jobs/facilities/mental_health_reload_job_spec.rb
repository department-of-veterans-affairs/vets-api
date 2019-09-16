# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::MentalHealthReloadJob, type: :job do

  class FakeMentalHealthClient
    def download
      [
        {
          "StationNumber"=>"101A", "MHPhone"=>"4071231234", "Extension"=>"0001", "Modified"=>"2019-08-07",
        },
        {
          "StationNumber"=>"202A", "MHPhone"=>"3211231234", "Extension"=>"0002", "Modified"=>"2019-08-07"
        }
      ]
    end
  end

  before(:each) do
    FacilityMentalHealth.keys.map{ |k| FacilityMentalHealth.delete(k) }

    allow(
      Facilities::MentalHealthClient
    ).to receive(:new).and_return(FakeMentalHealthClient.new)
  end

  it 'populates mental health data' do
    now = Time.now.utc.iso8601
    
    Facilities::MentalHealthReloadJob.new.perform

    facility = FacilityMentalHealth.find('101A')
    facility2 = FacilityMentalHealth.find('202A')

    expect(facility.station_number).to eq('101A')
    expect(facility.mh_phone).to eq('4071231234')
    expect(facility.mh_ext).to eq('0001')
    expect(facility.modified).to eq('2019-08-07')
    expect(facility.local_updated).to be >= now

    expect(facility2.station_number).to eq('202A')
    expect(facility2.mh_phone).to eq('3211231234')
    expect(facility2.mh_ext).to eq('0002')
    expect(facility2.modified).to eq('2019-08-07')
    expect(facility2.local_updated).to be >= now
  end


  it 'deletes removed keys' do
    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A')).to_not be_nil
    expect(FacilityMentalHealth.find('202A')).to_not be_nil

    mental_health_data = [{
        "StationNumber"=>"202A", "MHPhone"=>"3211231234", "MHExt"=>"0002", "Modified"=>"2019-08-07"
      }]

    allow_any_instance_of(
      FakeMentalHealthClient
    ).to receive(:download).and_return(mental_health_data)

    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A')).to be_nil
    expect(FacilityMentalHealth.find('202A')).to_not be_nil
  end

  it 'updates modified data' do
    now = Time.now.utc.iso8601
    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A')).to_not be_nil
    expect(FacilityMentalHealth.find('202A')).to_not be_nil
    expect(FacilityMentalHealth.find('101A').mh_phone).to eq('4071231234')
    expect(FacilityMentalHealth.find('202A').mh_phone).to eq('3211231234')
    expect(FacilityMentalHealth.find('101A').local_updated).to be >= now
    expect(FacilityMentalHealth.find('202A').local_updated).to be >= now
    later = Time.now.utc.iso8601

    # This data is the same as above EXCEPT for the phone number for 202A
    mental_health_data =       [{
          "StationNumber"=>"101A", "MHPhone"=>"4071231234", "MHExt"=>"0001", "Modified"=>"2019-08-07",
        },
        {
          "StationNumber"=>"202A", "MHPhone"=>"3219876543", "MHExt"=>"0002", "Modified"=>"2019-08-07"
        }]

    allow_any_instance_of(
      FakeMentalHealthClient
    ).to receive(:download).and_return(mental_health_data)

    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A')).to_not be_nil
    expect(FacilityMentalHealth.find('202A')).to_not be_nil
    expect(FacilityMentalHealth.find('101A').mh_phone).to eq('4071231234')
    expect(FacilityMentalHealth.find('202A').mh_phone).to eq('3219876543')
    expect(FacilityMentalHealth.find('101A').local_updated).to be >= now
    expect(FacilityMentalHealth.find('101A').local_updated).to be <= later
    expect(FacilityMentalHealth.find('202A').local_updated).to be >= later
  end

  context 'on error' do
    before do
      Settings.sentry.dsn = 'asdf'
    end
    after do
      Settings.sentry.dsn = nil
    end

    it 'logs mental health reload error to sentry' do
      allow_any_instance_of(
        Facilities::MentalHealthReloadJob
      ).to receive(:fetch_mental_health_data).and_raise(Facilities::MentalHealthDownloadError)
      expect(Raven).to receive(:capture_exception).with(Facilities::MentalHealthDownloadError, level: 'error')
      Facilities::MentalHealthReloadJob.new.perform
    end
  end
end
