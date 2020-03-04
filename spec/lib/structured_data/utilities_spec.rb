# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StructuredData::Utilities do
  let(:claim) { build(:burial_claim) }
  let(:bgs_service) { instance_double(LighthouseBGS::Services) }

  before do
    allow(LighthouseBGS::Services).to receive(:new).and_return(bgs_service)

    people_service = OpenStruct.new(find_dependents: { dependent: [] })
    allow(bgs_service).to receive(:people).and_return(people_service)
    allow(people_service).to receive(:find_dependents).and_return(
      dependent: [{
        ptcpnt_rlnshp_type_nm: 'Child',
        first_nm: 'First',
        last_nm: 'Last'
      }]
    )
  end

  describe '#find_dependents' do
    it 'calls LighthouseBGS::Services for claimant lookup' do
      expect(StructuredData::Utilities.find_dependents(123)).to eq(
        [{
          ptcpnt_rlnshp_type_nm: 'Child',
          first_nm: 'First',
          last_nm: 'Last'
        }]
      )
    end
  end

  describe '#find_dependent_claimant' do
    it 'returns dependent claimants that match claim form data' do
      expect(StructuredData::Utilities.find_dependent_claimant(
        OpenStruct.new(participant_id: 123),
        { 'first' => 'First', 'last' => 'Last'},
        { "street" => "claimant street" }
      )).to eq(
        {
          ptcpnt_rlnshp_type_nm: 'Child',
          first_nm: 'First',
          last_nm: 'Last'
        }
      )
    end
  end
end
