# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::PSSGDownload, type: :job do
  let(:drive_time_data) do
    fixture_file_name = "#{::Rails.root}/spec/fixtures/pssg/drive_time_data.json"
    File.open(fixture_file_name, 'rb') do |f|
      JSON.parse(f.read)
    end
  end

  let(:pssg_client_stub) { instance_double('Facilities::DrivetimeBandClient') }

  before do
    allow(Facilities::DrivetimeBandClient).to receive(:new, &method(:pssg_client_stub))
    allow(pssg_client_stub).to receive(:get_drivetime_bands).and_return(nil)
    allow(pssg_client_stub).to receive(:get_drivetime_bands).with(0, 1).and_return(drive_time_data)
  end

  describe 'matching facility' do
    before do
      create :vha_648A4
    end

    it 'populates facility with drive time data overriding existing band' do
      create :sixty_mins_648A4

      expect(BaseFacility.find_facility_by_id('vha_648A4').drivetime_bands[0].name).to eql('drive_time_band_^0')
      subject.perform
      expect(BaseFacility.find_facility_by_id('vha_648A4').drivetime_bands).not_to be_nil
      expect(BaseFacility.find_facility_by_id('vha_648A4').drivetime_bands.size).to be(1)
      expect(BaseFacility.find_facility_by_id('vha_648A4').drivetime_bands[0].name).to eql('648A4 : 0 - 10')
      expect(DrivetimeBand.find_by(vha_facility_id: '648A4').name).to eql('648A4 : 0 - 10')
    end

    it 'populates facility with drive time data' do
      subject.perform
      expect(BaseFacility.find_facility_by_id('vha_648A4').drivetime_bands).not_to be_nil
      expect(BaseFacility.find_facility_by_id('vha_648A4').drivetime_bands.size).to be(1)
      expect(BaseFacility.find_facility_by_id('vha_648A4').drivetime_bands[0].name).to eql('648A4 : 0 - 10')
      expect(DrivetimeBand.find_by(vha_facility_id: '648A4').name).to eql('648A4 : 0 - 10')
    end
  end

  describe 'no matching facility' do
    it 'populates facility with drive time data' do
      subject.perform
      expect(BaseFacility.find_facility_by_id('vha_648A4')).to be_nil
      expect(DrivetimeBand.find_by(name: '648A4 : 0 - 10')).to be_nil
    end
  end
end
