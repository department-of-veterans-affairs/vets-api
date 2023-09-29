# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Facilities::MentalHealthReloadJob, type: :job do
  let(:mental_phone_headers) { %w[StationNumber MHPhone Extension Modified] }
  let(:facility1) { CSV::Row.new(mental_phone_headers, ['101A', '407-123-1234', '0001', '2019-09-06T13:00:00.000']) }
  let(:facility2) { CSV::Row.new(mental_phone_headers, ['202A', '321-123-1234', '0002', '2019-09-06T13:00:00.000']) }

  before do
    allow_any_instance_of(
      Facilities::MentalHealthReloadJob
    ).to receive(:fetch_mental_health_data).and_return(CSV::Table.new([facility1, facility2]))
  end

  it 'populates mental health data' do
    now = Time.now.utc.iso8601

    Facilities::MentalHealthReloadJob.new.perform
    facility = FacilityMentalHealth.find('101A')
    facility2 = FacilityMentalHealth.find('202A')

    expect(facility.station_number).to eq('101A')
    expect(facility.mh_phone).to eq('407-123-1234')
    expect(facility.mh_ext).to eq('0001')
    expect(facility.modified).to eq('2019-09-06T13:00:00.000')
    expect(facility.local_updated).to be >= now

    expect(facility2.station_number).to eq('202A')
    expect(facility2.mh_phone).to eq('321-123-1234')
    expect(facility2.mh_ext).to eq('0002')
    expect(facility2.modified).to eq('2019-09-06T13:00:00.000')
    expect(facility2.local_updated).to be >= now
  end

  it 'deletes removed keys' do
    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A')).not_to be_nil
    expect(FacilityMentalHealth.find('202A')).not_to be_nil

    allow_any_instance_of(
      Facilities::MentalHealthReloadJob
    ).to receive(:fetch_mental_health_data).and_return(CSV::Table.new([facility2]))

    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A')).to be_nil
    expect(FacilityMentalHealth.find('202A')).not_to be_nil
  end

  xit 'updates modified data' do
    now = Time.now.utc.iso8601
    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A').mh_phone).to eq('407-123-1234')
    expect(FacilityMentalHealth.find('202A').mh_phone).to eq('321-123-1234')
    expect(FacilityMentalHealth.find('101A').local_updated).to be >= now
    expect(FacilityMentalHealth.find('202A').local_updated).to be >= now
    later = Time.now.utc.iso8601

    # This data is the same as above EXCEPT for the phone number for 202A
    mental_health_data = [
      facility1,
      CSV::Row.new(mental_phone_headers,
                   ['202A', '321-987-6543', '0002', '2019-09-06T13:00:00.000'])
    ]

    allow_any_instance_of(
      Facilities::MentalHealthReloadJob
    ).to receive(:fetch_mental_health_data).and_return(CSV::Table.new(mental_health_data))

    Facilities::MentalHealthReloadJob.new.perform
    expect(FacilityMentalHealth.find('101A').mh_phone).to eq('407-123-1234')
    expect(FacilityMentalHealth.find('202A').mh_phone).to eq('321-987-6543')
    expect(FacilityMentalHealth.find('101A').local_updated).to be >= now
    expect(FacilityMentalHealth.find('101A').local_updated).to be <= later
    expect(FacilityMentalHealth.find('202A').local_updated).to be >= later
  end

  it 'cleans up bad extension data' do
    mental_health_data = [
      CSV::Row.new(mental_phone_headers, ['101A', '407-123-1234', 'NULL', '2019-09-06T13:00:00.000']),
      CSV::Row.new(mental_phone_headers, ['202A', '321-123-1234', '0', '2019-09-06T13:00:00.000'])
    ]

    allow_any_instance_of(
      Facilities::MentalHealthReloadJob
    ).to receive(:fetch_mental_health_data).and_return(CSV::Table.new(mental_health_data))
    Facilities::MentalHealthReloadJob.new.perform

    expect(FacilityMentalHealth.find('101A')).not_to be_nil
    expect(FacilityMentalHealth.find('202A')).not_to be_nil
    expect(FacilityMentalHealth.find('101A').mh_ext).to eq(nil)
    expect(FacilityMentalHealth.find('202A').mh_ext).to eq(nil)
  end

  context 'when encountering an error' do
    before do
      allow(Settings.sentry).to receive(:dsn).and_return('asdf')
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
