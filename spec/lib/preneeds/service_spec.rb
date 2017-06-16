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
      discharge_types = VCR.use_cassette('preneeds/discharge_types/gets_a_list_of_discharge_types') do
        subject.get_discharge_types
      end

      expect(discharge_types).to be_a(Common::Collection)
      expect(discharge_types.type).to eq(DischargeType)
    end
  end

  describe 'get_attachment_types' do
    it 'gets a collection of attachment_types' do
      attachment_types = VCR.use_cassette('preneeds/attachment_types/gets_a_list_of_attachment_types') do
        subject.get_attachment_types
      end

      expect(attachment_types).to be_a(Common::Collection)
      expect(attachment_types.type).to eq(PreneedsAttachmentType)
    end
  end

  describe 'get_branches_of_service' do
    it 'gets a collection of service branches' do
      branches = VCR.use_cassette('preneeds/branches_of_service/gets_a_list_of_service_branches') do
        subject.get_branches_of_service
      end

      expect(branches).to be_a(Common::Collection)
      expect(branches.type).to eq(BranchesOfService)
    end
  end
end
