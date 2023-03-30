# frozen_string_literal: true

require 'rails_helper'
require 'mpi/messages/add_person_implicit_search_message'

describe MPI::Messages::AddPersonImplicitSearchMessage do
  let(:add_person_implicit_search_message) do
    described_class.new(last_name:,
                        ssn:,
                        birth_date:,
                        idme_uuid:,
                        logingov_uuid:,
                        email:,
                        address:,
                        first_name:)
  end

  let(:last_name) { 'some-last-name' }
  let(:ssn) { 'some-ssn' }
  let(:birth_date) { Formatters::DateFormatter.format_date('10-10-2021') }
  let(:idme_uuid) { 'some-idme-uuid' }
  let(:logingov_uuid) { 'some-logingov-uuid' }
  let(:email) { 'some-email' }
  let(:telecom_type) { 'H' }
  let(:first_name) { 'some-first-name' }
  let(:address) { nil }
  let(:csp_uuid) { idme_uuid }
  let(:csp_type) { MPI::Constants::IDME_IDENTIFIER }
  let(:csp_id) { "#{csp_uuid}^PN^#{csp_type}^USDVA^A" }

  describe '.perform' do
    subject { add_person_implicit_search_message.perform }

    shared_examples 'missing values response' do
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { "Required values missing: #{missing_keys}" }
      let(:expected_rails_log) { "[AddPersonImplicitSearchMessage] Failed to build request: #{expected_error_message}" }

      it 'raises an argument error and logs an error message to rails' do
        expect(Rails.logger).to receive(:error).with(expected_rails_log)
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when first name is not defined' do
      let(:first_name) { nil }
      let(:missing_keys) { [:first_name] }

      it_behaves_like 'missing values response'
    end

    context 'when last name is not defined' do
      let(:last_name) { nil }
      let(:missing_keys) { [:last_name] }

      it_behaves_like 'missing values response'
    end

    context 'when ssn is not defined' do
      let(:ssn) { nil }
      let(:missing_keys) { [:ssn] }

      it_behaves_like 'missing values response'
    end

    context 'when birth_date is not defined' do
      let(:birth_date) { nil }
      let(:missing_keys) { [:birth_date] }

      it_behaves_like 'missing values response'
    end

    shared_examples 'successfully built message' do
      let(:idm_path) { 'env:Envelope/env:Body/idm:PRPA_IN201301UV02' }
      let(:data_enterer_path) { "#{idm_path}/controlActProcess/dataEnterer" }
      let(:subject_path) { "#{idm_path}/controlActProcess/subject" }

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
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/telecom/@use", telecom_type
        )
        expect(subject).to eq_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/telecom/@value", email
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
        let(:missing_keys) { [:credential_identifier] }

        it_behaves_like 'missing values response'
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

    context 'when address is defined' do
      let(:address) do
        {
          street:,
          street2:,
          state:,
          city:,
          postal_code:,
          country:
        }
      end
      let(:street) { 'some-street' }
      let(:street2) { 'some-street-2' }
      let(:state) { 'some-state' }
      let(:city) { 'some-city' }
      let(:postal_code) { 'some-postal-code' }
      let(:country) { 'some-country' }
      let(:idm_path) { 'env:Envelope/env:Body/idm:PRPA_IN201301UV02' }
      let(:data_enterer_path) { "#{idm_path}/controlActProcess/dataEnterer" }
      let(:subject_path) { "#{idm_path}/controlActProcess/subject" }

      it 'creates a message with a street in address' do
        expect(subject).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/addr/streetAddressLine",
          "#{street} #{street2}"
        )
      end

      it 'creates a message with a city in address' do
        expect(subject).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/addr/city", city
        )
      end

      it 'creates a message with a state in address' do
        expect(subject).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/addr/state", state
        )
      end

      it 'creates a message with a postal code in address' do
        expect(subject).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/addr/postalCode", postal_code
        )
      end

      it 'creates a message with a country in address' do
        expect(subject).to eq_text_at_path(
          "#{subject_path}/registrationEvent/subject1/patient/patientPerson/addr/country", country
        )
      end
    end
  end
end
