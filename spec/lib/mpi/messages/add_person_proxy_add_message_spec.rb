# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/add_person_proxy_add_message'

describe MPI::Messages::AddPersonProxyAddMessage do
  let(:add_person_proxy_add_message) do
    described_class.new(first_name:,
                        last_name:,
                        ssn:,
                        birth_date:,
                        icn:,
                        edipi:,
                        search_token:)
  end

  let(:first_name) { 'some-first-name' }
  let(:last_name) { 'some-last-name' }
  let(:ssn) { 'some-ssn' }
  let(:birth_date) { Formatters::DateFormatter.format_date('10-10-2021') }
  let(:icn) { 'some-icn' }
  let(:icn_with_aaid) { "#{icn}^NI^200M^USVHA^P" }
  let(:edipi) { 'some-edipi' }
  let(:search_token) { 'some-search-token' }

  describe '.perform' do
    subject { add_person_proxy_add_message.perform }

    shared_examples 'error response' do
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { "Required values missing: #{[missing_keys]}" }
      let(:expected_rails_log) { "[AddPersonProxyAddMessage] Failed to build request: #{expected_error_message}" }

      it 'raises an argument error and logs an error message to rails' do
        expect(Rails.logger).to receive(:error).with(expected_rails_log)
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when first name is not defined' do
      let(:first_name) { nil }
      let(:missing_keys) { :first_name }

      it_behaves_like 'error response'
    end

    context 'when last name is not defined' do
      let(:last_name) { nil }
      let(:missing_keys) { :last_name }

      it_behaves_like 'error response'
    end

    context 'when ssn is not defined' do
      let(:ssn) { nil }
      let(:missing_keys) { :ssn }

      it_behaves_like 'error response'
    end

    context 'when birth_date is not defined' do
      let(:birth_date) { nil }
      let(:missing_keys) { :birth_date }

      it_behaves_like 'error response'
    end

    context 'when icn is not defined' do
      let(:icn) { nil }
      let(:missing_keys) { :icn }

      it_behaves_like 'error response'
    end

    context 'when edipi is not defined' do
      let(:edipi) { nil }
      let(:missing_keys) { :edipi }

      it_behaves_like 'error response'
    end

    context 'when search_token is not defined' do
      let(:search_token) { nil }
      let(:missing_keys) { :search_token }

      it_behaves_like 'error response'
    end

    context 'with a user that has all required attributes' do
      let(:idm_path) { 'env:Envelope/env:Body/idm:PRPA_IN201301UV02' }
      let(:data_enterer_path) { "#{idm_path}/controlActProcess/dataEnterer" }
      let(:subject_path) { "#{idm_path}/controlActProcess/subject" }
      let(:ip_address) { '1.1.1.1' }

      before { allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.ip(ip_address)]) }

      it 'has a USDSVA extension with a uuid' do
        expect(subject).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'has a sender extension' do
        expect(subject).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'has a receiver extension' do
        expect(subject).to eq_at_path("#{idm_path}/receiver/device/id/@root", '1.2.840.114350.1.13.999.234')
      end

      it 'has a creation time', run_at: 'Thu, 06 Feb 2020 23:59:36 GMT' do
        expect(subject).to eq_at_path("#{idm_path}/creationTime/@value", '20200206235936')
      end

      it 'has a search token' do
        expect(subject).to eq_text_at_path("#{idm_path}/attentionLine/value", search_token)
      end

      it 'has the proxy add orchestration node' do
        parsed_xml = Ox.parse(subject)
        nodes = parsed_xml.locate("#{subject_path}/registrationEvent/subject1/patient/patientPerson").first.nodes

        expect(nodes[3].locate('id/@extension').first).to eq('PROXY_ADD^PI^200VBA^USVBA')
        expect(nodes[3].locate('scopingOrganization/name').first.nodes.first).to eq('MVI.ORCHESTRATION')
      end

      it 'has a dataEnterer node' do
        xml = subject

        expect(xml).to eq_at_path("#{data_enterer_path}/@typeCode", 'ENT')
        expect(xml).to eq_at_path("#{data_enterer_path}/@contextControlCode", 'AP')
        expect(xml).to eq_at_path(
          "#{data_enterer_path}/assignedPerson/id/@extension", icn_with_aaid
        )
        expect(xml).to eq_text_at_path(
          "#{data_enterer_path}/assignedPerson/assignedPerson/name/given", first_name
        )
        expect(xml).to eq_text_at_path(
          "#{data_enterer_path}/assignedPerson/assignedPerson/name/family", last_name
        )
        expect(xml).to eq_at_path(
          "#{data_enterer_path}/assignedPerson/representedOrganization/id/@extension",
          "dslogon.#{edipi}"
        )
        expect(xml).to eq_text_at_path(
          "#{data_enterer_path}/assignedPerson/representedOrganization/desc", 'vagov'
        )
        expect(xml).to eq_at_path(
          "#{data_enterer_path}/assignedPerson/representedOrganization/telecom/@value", ip_address
        )
      end

      it 'has a subject node' do
        xml = subject

        expect(xml).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/id/@extension", icn_with_aaid
        )
        expect(xml).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/name/given", first_name
        )
        expect(xml).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/name/family", last_name
        )
        expect(xml).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/birthTime/@value",
          Date.parse(birth_date).strftime('%Y%m%d')
        )
        expect(xml).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/asOtherIDs/id/@extension", ssn
        )
      end
    end
  end
end
