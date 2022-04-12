# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/find_profile_message_edipi'

describe MPI::Messages::FindProfileMessageEdipi do
  describe '.to_xml' do
    context 'with edipi' do
      let(:edipi) { 'fake-edipi-number' }
      let(:xml) do
        described_class.new(edipi).to_xml
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
        expect(xml).to eq_at_path("#{parameter_list_path}/id/@root", '2.16.840.1.113883.3.42.10001.100001.12')
        expect(xml).to eq_at_path("#{parameter_list_path}/id/@extension", edipi)
      end

      context 'orchestration' do
        it 'has orchestration related params when enabled' do
          allow(Settings.mvi).to receive(:vba_orchestration).and_return(true)
          expect(xml).to eq_text_at_path(
            "#{parameter_list_path}/otherIDsScopingOrganization/semanticsText",
            'MVI.ORCHESTRATION'
          )
        end
      end
    end
  end
end
