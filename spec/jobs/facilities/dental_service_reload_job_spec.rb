# frozen_string_literal: true

require 'csv'
require 'rails_helper'

RSpec.describe Facilities::DentalServiceReloadJob, type: :job do
  let(:dental_service_data) do
    %(unique_id,facility_type\n402HB,va_health_facility\n436,va_health_facility\n436GH,va_health_facility)
  end

  before do
    allow_any_instance_of(
      Facilities::DentalServiceReloadJob
    ).to receive(:fetch_dental_service_data).and_return(CSV.parse(dental_service_data, headers: true))
  end

  it 'populates facilities' do
    Facilities::DentalServiceReloadJob.new.perform
    expect(FacilityDentalService.find('402HB')).not_to be_nil
    expect(FacilityDentalService.find('436')).not_to be_nil
    expect(FacilityDentalService.find('436GH')).not_to be_nil
  end

  it 'populates facility data' do
    now = Time.now.utc.iso8601
    Facilities::DentalServiceReloadJob.new.perform
    expect(FacilityDentalService.find('402HB').local_updated).to be >= now
  end

  it 'deletes removed keys' do
    Facilities::DentalServiceReloadJob.new.perform
    expect(FacilityDentalService.find('436GH')).not_to be_nil

    dental_service_data = %(unique_id,facility_type\n402HB,va_health_facility\n436,va_health_facility)

    allow_any_instance_of(
      Facilities::DentalServiceReloadJob
    ).to receive(:fetch_dental_service_data).and_return(CSV.parse(dental_service_data, headers: true))

    Facilities::DentalServiceReloadJob.new.perform
    expect(FacilityDentalService.find('436GH')).to be_nil
  end

  context 'when encountering an error' do
    before do
      allow(Settings.sentry).to receive(:dsn).and_return('asdf')
    end

    it 'logs mental health reload error to sentry' do
      allow_any_instance_of(
        Facilities::DentalServiceReloadJob
      ).to receive(:fetch_dental_service_data).and_raise(Facilities::DentalServiceError)
      expect(Raven).to receive(:capture_exception).with(Facilities::DentalServiceError, level: 'error')
      Facilities::DentalServiceReloadJob.new.perform
    end
  end
end
