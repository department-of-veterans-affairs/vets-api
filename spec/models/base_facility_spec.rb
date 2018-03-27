# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseFacility, type: :model do
  let(:bbox) { [-73.401, 40.685, -77.36, 43.03] }
  let(:nca_facility) { Facilities::NCAFacility.create(attrs) }
  let(:vba_facility) { Facilities::VBAFacility.create(attrs) }
  let(:vc_facility) { Facilities::VCFacility.create(attrs) }
  let(:vha_facility) { Facilities::VHAFacility.create(attrs) }

  describe 'VCFacility' do
    let(:attrs) {}
    it 'should save and retrieve all attributes and they should match the original object' do
    end
  end

  describe 'VHAFacility' do
  end

  describe 'VBAFacility' do
  end

  describe 'NCAFacility' do
  end
end
