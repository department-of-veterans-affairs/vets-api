# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/add_person_implicit_search_message'

describe MPI::Messages::AddPersonImplicitSearchMessage do
  let(:add_person_implicit_search_message) do
    described_class.new(last_name: last_name,
                        ssn: ssn,
                        birth_date: birth_date,
                        idme_uuid: idme_uuid,
                        logingov_uuid: logingov_uuid,
                        first_name: first_name)
  end

  let(:last_name) { 'some-last-name' }
  let(:ssn) { 'some-ssn' }
  let(:birth_date) { Formatters::DateFormatter.format_date('10-10-2021') }
  let(:idme_uuid) { 'some-idme-uuid' }
  let(:logingov_uuid) { 'some-logingov-uuid' }
  let(:first_name) { 'some-first-name' }
  let(:csp_uuid) { idme_uuid }
  let(:csp_type) { MPI::Constants::IDME_IDENTIFIER }
  let(:csp_id) { "#{csp_uuid}^PN^#{csp_type}^USDVA^A" }

  describe '.to_xml' do
    subject { add_person_implicit_search_message.to_xml }

    context 'when first name is not defined' do
      let(:first_name) { nil }
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { 'Add Person Implicit Search Missing Attributes' }

      it 'raises an argument error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when last name is not defined' do
      let(:last_name) { nil }
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { 'Add Person Implicit Search Missing Attributes' }

      it 'raises an argument error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when ssn is not defined' do
      let(:ssn) { nil }
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { 'Add Person Implicit Search Missing Attributes' }

      it 'raises an argument error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when birth_date is not defined' do
      let(:birth_date) { nil }
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { 'Add Person Implicit Search Missing Attributes' }

      it 'raises an argument error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    shared_examples 'successfully built message' do
      let(:idm_path) { 'soap:Envelope/soap:Body/idm:PRPA_IN201301UV02' }
      let(:data_enterer_path) { "#{idm_path}/controlActProcess/dataEnterer" }
      let(:subject_path) { "#{idm_path}/controlActProcess/subject" }

      it 'has a USDSVA extension with a uuid' do
        expect(subject).to match_at_path("#{idm_path}/id/@extension", /200VGOV-\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/)
      end

      it 'has a sender extension' do
        expect(subject).to eq_at_path("#{idm_path}/sender/device/id/@extension", '200VGOV')
      end

      it 'has a receiver extension' do
        expect(subject).to eq_at_path("#{idm_path}/receiver/device/id/@root", '2.16.840.1.113883.4.349')
      end

      it 'has a creation time', run_at: 'Thu, 06 Feb 2020 23:59:36 GMT' do
        expect(subject).to eq_at_path("#{idm_path}/creationTime/@value", '20200206235936')
      end

      it 'has a subject node' do
        expect(subject).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/name/given", first_name
        )
        expect(subject).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/name/family", last_name
        )
        expect(subject).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/birthTime/@value",
          Date.parse(birth_date).strftime('%Y%m%d')
        )
        expect(subject).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/asOtherIDs/id/@extension", ssn
        )
        expect(subject).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/id/@extension", csp_id
        )
      end
    end

    context 'when idme_uuid is not defined' do
      let(:idme_uuid) { nil }

      context 'and logingov_uuid is defined' do
        let(:logingov_uuid) { 'some-logingov-uuid' }
        let(:csp_uuid) { logingov_uuid }
        let(:csp_type) { MPI::Constants::LOGINGOV_IDENTIFIER }

        it_behaves_like 'successfully built message'
      end

      context 'and logingov_uuid is not defined' do
        let(:logingov_uuid) { nil }
        let(:expected_error) { MPI::Errors::ArgumentError }
        let(:expected_error_message) { 'Add Person Implicit Search Missing Attributes' }

        it 'raises an argument error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when idme_uuid is defined' do
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:csp_uuid) { idme_uuid }
      let(:csp_type) { MPI::Constants::IDME_IDENTIFIER }

      context 'and logingov_uuid is defined' do
        let(:logingov_uuid) { 'some-logingov-uuid' }

        it_behaves_like 'successfully built message'
      end

      context 'and logingov_uuid is not defined' do
        let(:logingov_uuid) { nil }

        it_behaves_like 'successfully built message'
      end
    end
  end
end
