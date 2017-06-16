# frozen_string_literal: true
require 'rails_helper'
require 'preneeds/service'

describe Preneeds::Service do
  let(:subject) { described_class.new }

  describe 'get_cemeteries' do
    it 'gets a collection of cemeteries' do
      cemeteries = VCR.use_cassette('preneeds/cemeteries/gets_a_list_of_cemeteries') do
        subject.get_cemeteries
      end

      expect(cemeteries).to be_a(Common::Collection)
      expect(cemeteries.type).to eq(Cemetery)
    end
  end

  describe 'get_states' do
    it 'gets a collection of states' do
      states = VCR.use_cassette('preneeds/states/gets_a_list_of_states') do
        subject.get_states
      end

      expect(states).to be_a(Common::Collection)
      expect(states.type).to eq(PreneedsState)
    end
  end

  describe 'get_discharge_types' do
    it 'gets a collection of discharge_types' do
      states = VCR.use_cassette('preneeds/discharge_types/gets_a_list_of_discharge_types') do
        subject.get_discharge_types
      end

      expect(states).to be_a(Common::Collection)
      expect(states.type).to eq(DischargeType)
    end
  end

  describe 'get_attachment_types' do
    it 'gets a collection of attachment_types' do
      states = VCR.use_cassette('preneeds/attachment_types/gets_a_list_of_attachment_types') do
        subject.get_attachment_types
      end

      expect(states).to be_a(Common::Collection)
      expect(states.type).to eq(PreneedsAttachmentType)
    end
  end
end
