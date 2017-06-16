# frozen_string_literal: true
require 'rails_helper'
require 'burials/service'

describe Burials::Service do
  let(:subject) { described_class.new }

  describe 'get_cemeteries' do
    it 'gets a collection of cemeteries' do
      cemeteries = VCR.use_cassette('burials/cemeteries/gets_a_list_of_cemeteries') do
        subject.get_cemeteries
      end

      expect(cemeteries).to be_a(Common::Collection)
      expect(cemeteries.type).to eq(Cemetery)
    end
  end

  describe 'get_states' do
    it 'gets a collection of states' do
      states = VCR.use_cassette('burials/states/gets_a_list_of_states') do
        subject.get_states
      end

      expect(states).to be_a(Common::Collection)
      expect(states.type).to eq(BurialState)
    end
  end

  describe 'get_discharge_types' do
    it 'gets a collection of discharge_types' do
      states = VCR.use_cassette('burials/discharge_types/gets_a_list_of_discharge_types') do
        subject.get_discharge_types
      end

      expect(states).to be_a(Common::Collection)
      expect(states.type).to eq(DischargeType)
    end
  end
end
