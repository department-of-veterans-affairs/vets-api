# frozen_string_literal: true

require 'rails_helper'
require 'mvi/messages/add_person_message'

describe MVI::Messages::AddPersonMessage do
  let(:xml) { described_class.new(user).to_xml }

  describe '.to_xml' do
    context 'with a user that has all required attributes' do
      let(:user) { build(:user, :loa3) }

      let(:idm_path) { 'soap:Envelope/soap:Body/idm:PRPA_IN201301UV02' }
      let(:data_enterer_path) { "#{idm_path}/controlActProcess/dataEnterer" }
      let(:subject_path) { "#{idm_path}/controlActProcess/subject" }

      it 'has a USDSVA extension with a uuid' do
        expect(xml).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'has a sender extension' do
        expect(xml).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'has a receiver extension' do
        expect(xml).to eq_at_path("#{idm_path}/receiver/device/id/@root", '2.16.840.1.113883.4.349')
      end

      it 'has a creation time', run_at: 'Thu, 06 Feb 2020 23:59:36 GMT' do
        expect(xml).to eq_at_path("#{idm_path}/creationTime/@value", '20200206235936')
      end

      it 'has a search token' do
        expect(xml).to eq_text_at_path("#{idm_path}/attentionLine/value", user.search_token)
      end

      it 'has the proxy add orchestration node' do
        parsed_xml = Ox.parse(xml)
        nodes = parsed_xml.locate("#{subject_path}/registrationEvent/subject1/patient/patientPerson").first.nodes

        expect(nodes[3].locate('id/@extension').first).to eq('PROXY_ADD^PI^200VBA^USVBA')
        expect(nodes[3].locate('scopingOrganization/name').first.nodes.first).to eq('MVI.ORCHESTRATION')
      end

      it 'has a dataEnterer node' do
        allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.ip('1.1.1.1')])

        expect(xml).to eq_at_path("#{data_enterer_path}/@typeCode", 'ENT')
        expect(xml).to eq_at_path("#{data_enterer_path}/@contextControlCode", 'AP')
        expect(xml).to eq_at_path(
          "#{data_enterer_path}/assignedPerson/id/@extension", user.icn_with_aaid
        )
        expect(xml).to eq_text_at_path(
          "#{data_enterer_path}/assignedPerson/assignedPerson/name/given", user.first_name
        )
        expect(xml).to eq_text_at_path(
          "#{data_enterer_path}/assignedPerson/assignedPerson/name/family", user.last_name
        )
        expect(xml).to eq_at_path(
          "#{data_enterer_path}/assignedPerson/representedOrganization/id/@extension",
          "dslogon.#{user.edipi}"
        )
        expect(xml).to eq_text_at_path(
          "#{data_enterer_path}/assignedPerson/representedOrganization/desc", 'vagov'
        )
        expect(xml).to eq_at_path(
          "#{data_enterer_path}/assignedPerson/representedOrganization/telecom/@value",
          '1.1.1.1'
        )
      end

      it 'has a subject node' do
        expect(xml).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/id/@extension", user.icn_with_aaid
        )
        expect(xml).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/name/given", user.first_name
        )
        expect(xml).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/name/family", user.last_name
        )
        expect(xml).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/birthTime/@value",
          Date.parse(user.birth_date).strftime('%Y%m%d')
        )
        expect(xml).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/asOtherIDs/id/@extension",
          user.ssn
        )
      end
    end

    context 'missing arguments' do
      let(:user) { build(:user, :loa3, user_hash) }

      let(:user_hash) do
        {
          first_name: 'MARK',
          last_name: 'WEBB',
          middle_name: '',
          birth_date: '1950-10-04',
          ssn: nil,
          dslogon_edipi: '1013590059'
        }
      end

      it 'throws an argument error' do
        expect do
          xml
        end.to raise_error(ArgumentError, 'User missing attributes')
      end
    end
  end
end
