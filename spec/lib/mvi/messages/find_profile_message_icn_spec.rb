# frozen_string_literal: true

require 'rails_helper'
require 'mvi/messages/find_profile_message'

describe MVI::Messages::FindProfileMessageIcn do
  describe '.to_xml' do
    context 'with icn' do
      let(:icn) { 'fake-icn-number' }
      let(:xml) do
        described_class.new(icn).to_xml
      end
      let(:idm_path) { 'env:Body/idm:PRPA_IN201305UV02' }
      let(:parameter_list_path) { "#{idm_path}/controlActProcess/queryByParameter/parameterList" }

      it 'has a USDSVA extension with a uuid' do
        expect(xml).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'has a sender extension' do
        expect(xml).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'has a receiver extension' do
        expect(xml).to eq_at_path("#{idm_path}/receiver/device/id/@extension", '200M')
      end

      it 'does not have a dataEnterer node' do
        expect(xml).not_to eq_at_path("#{idm_path}/controlActProcess/dataEnterer/@typeCode", 'ENT')
      end

      it 'has an icn/id node' do
        expect(xml).to eq_at_path("#{parameter_list_path}/id/@root", '2.16.840.1.113883.4.349')
        expect(xml).to eq_at_path("#{parameter_list_path}/id/@extension", icn)
      end
    end
  end
end
