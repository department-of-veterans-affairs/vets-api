# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'SSOe' do
    subject { described_class.new(saml_response) }

    let(:authn_context) { LOA::IDME_LOA1_VETS }
    let(:highest_attained_loa) { '1' }
    let(:multifactor) { false }
    let(:existing_saml_attributes) { nil }
    let(:login_uuid) { '1234567890' }
    let(:callback_url) { 'http://http://127.0.0.1:3000/v1/sessions/callback/v1/sessions/callback' }
    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        level_of_assurance: [highest_attained_loa],
        attributes: saml_attributes,
        existing_attributes: existing_saml_attributes,
        in_response_to: login_uuid,
        issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
      )
    end

    context 'mapped attributes' do
      let(:saml_attributes) do
        build(:ssoe_idme_loa1,
              va_eauth_firstname: ['NOT_FOUND'],
              va_eauth_lastname: ['NOT_FOUND'],
              va_eauth_gender: ['NOT_FOUND'])
      end

      it 'maps NOT_FOUND attributes to nil' do
        expect(subject.to_hash[:first_name]).to be_nil
        expect(subject.to_hash[:last_name]).to be_nil
        expect(subject.to_hash[:gender]).to be_nil
      end
    end

    context 'male gender user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1, va_eauth_gender: ['male']) }

      it 'maps male gender value' do
        expect(subject.to_hash[:gender]).to eq('M')
      end
    end

    context 'female gender user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1, va_eauth_gender: ['female']) }

      it 'maps female gender value' do
        expect(subject.to_hash[:gender]).to eq('F')
      end
    end

    context 'user with birth date' do
      let(:saml_attributes) { build(:ssoe_idme_loa3) }

      it 'coerces birth date to ISO 8601 format' do
        expect(subject.to_hash[:birth_date]).to eq('1969-04-07')
      end
    end

    context 'user without birth date' do
      let(:saml_attributes) do
        build(:ssoe_idme_loa3,
              va_eauth_birthDate_v1: ['NOT_FOUND'])
      end

      it 'returns nil' do
        expect(subject.to_hash[:birth_date]).to be_nil
      end
    end

    context 'user with partial birth date' do
      let(:saml_attributes) do
        build(:ssoe_idme_loa3,
              va_eauth_birthDate_v1: ['1980'])
      end

      it 'returns nil' do
        expect(subject.to_hash[:birth_date]).to be_nil
      end
    end

    context 'Login.gov IAL1 user' do
      let(:authn_context) { IAL::LOGIN_GOV_IAL1 }
      let(:saml_attributes) { build(:ssoe_logingov_ial1) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          email: 'testemail@test.com',
          phone: nil,
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          common_name: nil,
          suffix: nil,
          address: {
            street: nil,
            street2: nil,
            city: nil,
            state: nil,
            country: nil,
            postal_code: nil
          },
          zip: nil,
          gender: nil,
          ssn: nil,
          birth_date: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          idme_uuid: nil,
          logingov_uuid: '54e78de6140d473f87960f211be49c08',
          verified_at: nil,
          sec_id: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          edipi: nil,
          loa: { current: 1, highest: 1 },
          sign_in: {
            service_name: 'logingov',
            account_type: 'N/A'
          },
          multifactor: true,
          participant_id: nil,
          birls_id: nil,
          icn: nil,
          person_types: [],
          vha_facility_ids: nil,
          vha_facility_hash: nil,
          authn_context: authn_context
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      it 'passes ID.me UUID validation with a Login.gov UUID' do
        expect { subject.validate! }.not_to raise_error
      end
    end

    context 'Login.gov IAL2 user' do
      let(:authn_context) { IAL::LOGIN_GOV_IAL1 }
      let(:saml_attributes) { build(:ssoe_logingov_ial2) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1982-04-12',
          first_name: 'ROBERT',
          last_name: 'TESTER',
          common_name: 'vets.gov.user+1000@example.com',
          suffix: nil,
          address: {
            street: '123 Fantasy Lane',
            street2: nil,
            city: 'Seattle',
            state: 'WA',
            country: nil,
            postal_code: '39876'
          },
          middle_name: 'LOGIN',
          gender: 'M',
          ssn: '1231231',
          zip: '39876',
          mhv_icn: '1200049153V217987',
          mhv_correlation_id: '123456',
          mhv_account_type: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          edipi: nil,
          uuid: 'aa478abc-e494-4af1-9f87-d002f8fe1cda',
          email: 'vets.gov.user+1000@example.com',
          phone: '(123)123-1234',
          idme_uuid: nil,
          logingov_uuid: 'aa478abc-e494-4af1-9f87-d002f8fe1cda',
          verified_at: '2021-10-28T23:54:46Z',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'logingov', account_type: 'N/A' },
          sec_id: '1200049153',
          participant_id: nil,
          birls_id: nil,
          icn: '1200049153V217987',
          person_types: [],
          vha_facility_ids: %w[200MHS 200M 200M],
          vha_facility_hash: {
            '200M' => %w[987656789 123456789],
            '200MHS' => %w[123456]
          },
          multifactor: true,
          authn_context: authn_context
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      it 'passes ID.me UUID validation with a Login.gov UUID' do
        expect { subject.validate! }.not_to raise_error
      end
    end

    context 'unproofed IDme LOA1 user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1_unproofed) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context: authn_context,
          birth_date: nil,
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: nil,
          verified_at: nil,
          multifactor: false,
          loa: { current: 1, highest: 1 },
          sign_in: {
            service_name: 'idme',
            account_type: 'N/A'
          },
          sec_id: nil,
          participant_id: nil,
          birls_id: nil,
          icn: nil,
          common_name: nil,
          person_types: [],
          suffix: nil,
          address: {
            street: nil,
            street2: nil,
            city: nil,
            state: nil,
            country: nil,
            postal_code: nil
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: nil,
          vha_facility_hash: nil
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'previously proofed IDme LOA1 user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context: authn_context,
          birth_date: nil,
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: nil,
          verified_at: nil,
          multifactor: true,
          loa: { current: 1, highest: 3 },
          sign_in: {
            service_name: 'idme',
            account_type: 'N/A'
          },
          sec_id: nil,
          participant_id: nil,
          birls_id: nil,
          icn: nil,
          common_name: nil,
          person_types: [],
          suffix: nil,
          address: {
            street: nil,
            street2: nil,
            city: nil,
            state: nil,
            country: nil,
            postal_code: nil
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: nil,
          vha_facility_hash: nil
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'IDme LOA3 user' do
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:saml_attributes) { build(:ssoe_idme_loa3) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context: authn_context,
          birth_date: '1969-04-07',
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          suffix: nil,
          gender: 'M',
          ssn: '666271152',
          address: {
            street: '999 Pizza Place',
            street2: nil,
            city: 'Dallas',
            state: 'TX',
            postal_code: '77665',
            country: nil
          },
          zip: '77665',
          mhv_icn: '1008830476V316605',
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          phone: '(123)456-7890',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: nil,
          verified_at: nil,
          multifactor: true,
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          sec_id: '1008830476',
          participant_id: nil,
          birls_id: nil,
          icn: '1008830476V316605',
          common_name: 'vets.gov.user+262@example.com',
          person_types: [],
          cerner_id: '123456',
          cerner_facility_ids: %w[200MHV],
          vha_facility_ids: %w[200CRNR 200MHV],
          vha_facility_hash: { '200CRNR' => %w[123456], '200MHV' => %w[123456] }
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'MHV non premium user' do
      let(:authn_context) { 'myhealthevet' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_advanced) }
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context: authn_context,
          edipi: nil,
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          mhv_account_type: 'Advanced',
          uuid: '881571066e5741439652bc80759dd88c',
          email: 'alexmac_0@example.com',
          idme_uuid: '881571066e5741439652bc80759dd88c',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Advanced' },
          sec_id: nil,
          participant_id: nil,
          birls_id: nil,
          icn: nil,
          multifactor: multifactor,
          common_name: nil,
          person_types: [],
          suffix: nil,
          address: {
            street: nil,
            street2: nil,
            city: nil,
            state: nil,
            country: nil,
            postal_code: nil
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: nil,
          vha_facility_hash: nil
        )
      end

      it 'has an mhv_account_type set' do
        expect(subject.to_hash).to include(
          mhv_account_type: 'Advanced'
        )
      end
    end

    context 'MHV non premium user who verifies' do
      let(:authn_context) { 'myhealthevet_loa3' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_loa3) }
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1988-11-24',
          authn_context: authn_context,
          edipi: nil,
          first_name: 'ALEX',
          last_name: 'MAC',
          middle_name: nil,
          gender: 'F',
          ssn: '230595111',
          zip: '20571-0001',
          mhv_icn: '1013183292V131165',
          mhv_correlation_id: '15001594',
          mhv_account_type: 'Advanced',
          uuid: '881571066e5741439652bc80759dd88c',
          email: 'alexmac_0@example.com',
          idme_uuid: '881571066e5741439652bc80759dd88c',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Advanced' },
          sec_id: '1013183292',
          participant_id: nil,
          birls_id: nil,
          icn: '1013183292V131165',
          multifactor: multifactor,
          common_name: 'alexmac_0@example.com',
          person_types: [],
          suffix: nil,
          address: {
            street: '811 Vermont Ave NW',
            street2: nil,
            city: 'Washington',
            state: 'DC',
            country: 'USA',
            postal_code: '20571-0001'
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: %w[200MHS],
          vha_facility_hash: { '200MHS' => %w[15001594] }
        )
      end
    end

    context 'MHV non premium user who adds multifactor' do
      let(:authn_context) { 'myhealthevet_multifactor' }
      let(:highest_attained_loa) { '1' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_basic_multifactor) }
      let(:multifactor) { false }
      let(:existing_saml_attributes) { build(:ssoe_idme_mhv_basic_singlefactor) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context: authn_context,
          edipi: nil,
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          mhv_account_type: 'Basic',
          uuid: '72782a87a807407f83e8a052d804d7f7',
          email: 'pv+mhvtestb@example.com',
          idme_uuid: '72782a87a807407f83e8a052d804d7f7',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 1, highest: 1 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'Basic'
          },
          sec_id: nil,
          birls_id: nil,
          icn: nil,
          participant_id: nil,
          multifactor: true,
          common_name: nil,
          person_types: [],
          suffix: nil,
          address: {
            street: nil,
            street2: nil,
            city: nil,
            state: nil,
            country: nil,
            postal_code: nil
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: nil,
          vha_facility_hash: nil
        )
      end

      it 'is changing multifactor' do
        expect(subject).to be_changing_multifactor
      end
    end

    context 'MHV premium user' do
      let(:authn_context) { 'myhealthevet' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_premium) }
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1977-03-07',
          authn_context: authn_context,
          edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          zip: '56473',
          mhv_icn: '1012853550V207686',
          mhv_correlation_id: '12345748',
          mhv_account_type: 'Premium',
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'k+tristanmhv@example.com',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'Premium'
          },
          sec_id: '1012853550',
          participant_id: nil,
          birls_id: nil,
          icn: '1012853550V207686',
          multifactor: multifactor,
          common_name: 'k+tristan@example.com',
          person_types: [],
          suffix: nil,
          address: {
            street: '954 Bourbon Way',
            street2: nil,
            city: 'Lexington',
            state: 'KY',
            country: 'USA',
            postal_code: '56473'
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: %w[989 979 200MH 983 984 200MHS],
          vha_facility_hash: {
            '989' => %w[552151510],
            '979' => %w[943571],
            '200MH' => %w[12345748],
            '983' => %w[7219295],
            '984' => %w[552161765],
            '200MHS' => %w[12345748]
          }
        )
      end
    end

    context 'MHV premium user no idme uuid' do
      let(:authn_context) { 'myhealthevet' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) do
        build(:ssoe_idme_mhv_premium,
              va_eauth_uid: ['NOT_FOUND'],
              va_eauth_csid: ['NOT_FOUND'],
              va_eauth_gcIds: ['2107307560^NI^200DOD^USDOD^A|'])
      end
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1977-03-07',
          authn_context: authn_context,
          edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          zip: '56473',
          mhv_icn: '1012853550V207686',
          mhv_correlation_id: '12345748',
          mhv_account_type: 'Premium',
          uuid: Digest::UUID.uuid_v3('sec-id', '1012853550').tr('-', ''),
          email: 'k+tristanmhv@example.com',
          idme_uuid: nil,
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'Premium'
          },
          sec_id: '1012853550',
          participant_id: nil,
          birls_id: nil,
          icn: nil,
          multifactor: multifactor,
          common_name: 'k+tristan@example.com',
          person_types: [],
          suffix: nil,
          address: {
            street: '954 Bourbon Way',
            street2: nil,
            city: 'Lexington',
            state: 'KY',
            country: 'USA',
            postal_code: '56473'
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: nil,
          vha_facility_hash: nil
        )
      end
    end

    context 'MHV user' do
      let(:authn_context) { 'myhealthevet_loa3' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }

      context 'with an identifier from credential provider' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: ['999888'],
                va_eauth_gcIds: ['nothing'])
        end

        it 'resolves mhv id' do
          expect(subject.to_hash).to include(
            mhv_correlation_id: '999888'
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with an identifier from person index' do
        let(:mhv_ien) { '12334567890' }
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: ['NOT_FOUND'],
                va_eauth_gcIds: ["#{mhv_ien}^PI^200MHS^USVHA^A"])
        end

        it 'resolves mhv id' do
          expect(subject.to_hash).to include(
            mhv_correlation_id: mhv_ien
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with matching identifiers' do
        let(:mhv_ien) { '1234567890' }
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: [mhv_ien],
                va_eauth_gcIds: ["#{mhv_ien}^PI^200MHS^USVHA^A"])
        end

        it 'resolves mhv id' do
          expect(subject.to_hash).to include(
            mhv_correlation_id: mhv_ien
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with mismatching identifiers' do
        let(:mhv_uuid) { '999888' }
        let(:mhv_ien) { '888777' }
        let(:mhv_icn) { '123456789V98765431' }
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: [mhv_uuid],
                va_eauth_gcIds: ["#{mhv_ien}^PI^200MHS^USVHA^A"],
                va_eauth_icn: [mhv_icn])
        end
        let(:expected_error) { SAML::UserAttributeError::ERRORS[:multiple_mhv_ids] }
        let(:expected_error_data) { { mismatched_ids: [mhv_ien, mhv_uuid], icn: mhv_icn } }
        let(:expected_error_message) { expected_error[:message] }
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}, #{expected_error_data}" }

        it 'resolves mhv id from credential provider' do
          expect(subject.to_hash).to include(
            mhv_correlation_id: mhv_uuid
          )
        end

        context 'normal validation flow' do
          it 'does not validate and throws an error' do
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }.to raise_error { |error|
              expect(error).to be_a(SAML::UserAttributeError)
              expect(error.message).to eq(expected_error_message)
            }
          end
        end

        context 'MHV outbound-redirect flow' do
          it 'does not validate and logs a Sentry warning' do
            SAMLRequestTracker.create(
              uuid: '1234567890',
              payload: { skip_dupe_id_validation: 'true' }
            )
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }.not_to raise_error
          end
        end
      end

      context 'with mismatching ICNs' do
        let(:va_eauth_icn) { '22222222V888888' }
        let(:va_eauth_mhvicn) { '111111111V666666' }
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvicn: [va_eauth_mhvicn],
                va_eauth_icn: [va_eauth_icn])
        end
        let(:expected_error_data) { { mismatched_ids: [va_eauth_icn, va_eauth_mhvicn], icn: va_eauth_icn } }
        let(:expected_error_message) { SAML::UserAttributeError::ERRORS[:mhv_icn_mismatch][:message] }
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}, #{expected_error_data}" }

        context 'normal validation flow' do
          it 'does not validate' do
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }.to raise_error { |error|
              expect(error).to be_a(SAML::UserAttributeError)
              expect(error.message).to eq(expected_error_message)
            }
          end
        end

        context 'MHV outbound-redirect flow' do
          it 'does not validate and logs a Sentry warning' do
            SAMLRequestTracker.create(
              uuid: '1234567890',
              payload: { skip_dupe_id_validation: 'true' }
            )
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }.not_to raise_error
          end
        end
      end

      context 'with multi-value mhvien' do
        let(:gcids) { "#{first_ien}^PI^200MHS^USVHA^A|#{second_ien}^PI^200MHS^USVHA^A" }
        let(:mhv_icn) { '123456789V98765431' }
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: [uuid],
                va_eauth_gcIds: [gcids],
                va_eauth_icn: [mhv_icn])
        end

        context 'with matching values' do
          let(:uuid) { 'NOT_FOUND' }
          let(:first_ien) { '888777' }
          let(:second_ien) { '888777' }

          it 'de-duplicates values' do
            expect(subject.to_hash).to include(
              mhv_correlation_id: '888777'
            )
          end

          it 'validates' do
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'with uuid only' do
          let(:uuid) { '888777' }
          let(:gcids) { 'nothing' }

          it 'de-duplicates values' do
            expect(subject.to_hash).to include(
              mhv_correlation_id: '888777'
            )
          end

          it 'validates' do
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'with no mhv ids' do
          let(:uuid) { 'NOT_FOUND' }
          let(:gcids) { 'nothing' }

          it 'de-duplicates values' do
            expect(subject.to_hash).to include(
              mhv_correlation_id: nil
            )
          end

          it 'validates' do
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'with matching active mhvien from gcids and mhvuuid' do
          let(:uuid) { '888777' }
          let(:first_ien) { '888777' }
          let(:second_ien) { '888777' }

          it 'de-duplicates values' do
            expect(subject.to_hash).to include(
              mhv_correlation_id: '888777'
            )
          end

          it 'validates' do
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'with mis-matching active mhvien from gcids and mhvuuid' do
          let(:uuid) { '888777' }
          let(:first_ien) { '999888' }
          let(:second_ien) { '888777' }
          let(:expected_error) { SAML::UserAttributeError::ERRORS[:multiple_mhv_ids] }
          let(:expected_error_data) { { mismatched_ids: [first_ien, second_ien], icn: mhv_icn } }
          let(:expected_error_message) { expected_error[:message] }
          let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}, #{expected_error_data}" }

          it 'does not validate' do
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }
              .to raise_error { |error|
                expect(error).to be_a(SAML::UserAttributeError)
                expect(error.message).to eq(expected_error_message)
              }
          end
        end

        context 'with mis-matching active mhvien values from gcids' do
          let(:uuid) { 'NOT_FOUND' }
          let(:first_ien) { '999888' }
          let(:second_ien) { '888777' }
          let(:expected_error) { SAML::UserAttributeError::ERRORS[:multiple_mhv_ids] }
          let(:expected_error_data) { { mismatched_ids: [first_ien, second_ien], icn: mhv_icn } }
          let(:expected_error_message) { expected_error[:message] }
          let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}, #{expected_error_data}" }

          it 'does not validate' do
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }
              .to raise_error { |error|
                expect(error).to be_a(SAML::UserAttributeError)
                expect(error.message).to eq(expected_error_message)
              }
          end
        end
      end
    end

    context 'with multi-value birls_id' do
      let(:saml_attributes) do
        build(:ssoe_idme_mhv_loa3,
              va_eauth_birlsfilenumber: [birls_id])
      end

      context 'with different values' do
        let(:birls_id) { '0123456789,0000000054' }

        it 'logs warning to sentry' do
          expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
            'User attributes contain multiple distinct BIRLS ID values.',
            'warn',
            { birls_ids: birls_id }
          )
          subject.validate!
        end
      end
    end

    context 'with multi-value sec_id string' do
      let(:saml_attributes) do
        build(:ssoe_idme_mhv_loa3, va_eauth_secid: [sec_id])
      end

      context 'with one id string' do
        let(:sec_id) { '1234567890' }

        it 'will not log a warning to sentry' do
          expect_any_instance_of(SentryLogging).not_to receive(:log_message_to_sentry).with(
            'User attributes contains multiple sec_id values',
            'warn',
            { sec_id: sec_id }
          )
          subject.validate!
        end
      end

      context 'with two ids string' do
        let(:sec_id) { '1234567890,0987654321' }

        it 'will log a warning to sentry' do
          expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
            'User attributes contains multiple sec_id values',
            'warn',
            { sec_id: sec_id }
          )
          subject.validate!
        end
      end
    end

    context 'with multi-value corp_id' do
      let(:mhv_icn) { '123456789V98765431' }
      let(:saml_attributes) do
        build(:ssoe_idme_mhv_loa3,
              va_eauth_gcIds: [corp_id],
              va_eauth_icn: [mhv_icn])
      end
      let(:first_corp_id) { '0123456789' }
      let(:second_corp_id) { '0000000054' }
      let(:corp_id) { "#{first_corp_id}^PI^200CORP^USVBA^A|#{second_corp_id}^PI^200CORP^USVBA^A" }

      context 'with different values' do
        let(:expected_error) { SAML::UserAttributeError::ERRORS[:multiple_corp_ids] }
        let(:expected_error_data) { { mismatched_ids: [first_corp_id, second_corp_id], icn: mhv_icn } }
        let(:expected_error_message) { expected_error[:message] }
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}, #{expected_error_data}" }

        context 'regular auth flow' do
          it 'does not validate and prevents login' do
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }
              .to raise_error { |error|
                    expect(error).to be_a(SAML::UserAttributeError)
                    expect(error.message).to eq(expected_error_message)
                  }
          end
        end

        context 'MHV outbound-redirect flow' do
          it 'logs a Sentry warning and allows login' do
            SAMLRequestTracker.create(
              uuid: '1234567890',
              payload: { skip_dupe_id_validation: 'true' }
            )
            expect(Rails.logger).to receive(:warn).with(expected_log)
            expect { subject.validate! }.not_to raise_error
          end
        end
      end
    end

    context 'with multi-value edipi' do
      let(:mhv_icn) { '123456789V98765431' }
      let(:saml_attributes) do
        build(:ssoe_idme_mhv_loa3,
              va_eauth_gcIds: [edipi],
              va_eauth_icn: [mhv_icn])
      end
      let(:edipi) { "#{first_edipi}^NI^200DOD^USDOD^A|#{second_edipi}^NI^200DOD^USDOD^A|" }

      context 'with different values' do
        let(:first_edipi) { '0123456789' }
        let(:second_edipi) { '0000000054' }
        let(:expected_error) { SAML::UserAttributeError::ERRORS[:multiple_edipis] }
        let(:expected_error_data) { { mismatched_ids: [first_edipi, second_edipi], icn: mhv_icn } }
        let(:expected_error_message) { expected_error[:message] }
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}, #{expected_error_data}" }

        it 'does not validate' do
          expect(Rails.logger).to receive(:warn).with(expected_log)
          expect { subject.validate! }
            .to raise_error { |error|
                  expect(error).to be_a(SAML::UserAttributeError)
                  expect(error.message).to eq('User attributes contain multiple distinct EDIPI values')
                }
        end
      end

      context 'with matching values' do
        let(:first_edipi) { '0123456789' }
        let(:second_edipi) { first_edipi }

        it 'de-duplicates values' do
          expect(subject.to_hash).to include(
            edipi: '0123456789'
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with empty value' do
        let(:edipi) { '' }

        it 'de-duplicates values' do
          expect(subject.to_hash).to include(
            edipi: nil
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end
    end

    context 'DSLogon non premium user' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level1) }

      xit 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context: authn_context,
          edipi: '1606997570',
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 1, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: '1'
          },
          sec_id: nil,
          participant_id: nil,
          birls_id: nil,
          icn: nil,
          multifactor: multifactor,
          person_types: []
        )
      end
    end

    context 'DSLogon premium user without multifactor' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) do
        build(:ssoe_idme_dslogon_level2_singlefactor,
              va_eauth_gcIds: ['1013173963V366678^NI^200M^USVHA^P|'\
                               '2106798217^NI^200DOD^USDOD^A'\
                               '363761e8857642f7b77ef7d99200e711^PN^200VIDM^USDVA^A|'\
                               '2106798217^NI^200DOD^USDOD^A|'\
                               '1013173963^PN^200PROV^USDVA^A'])
      end

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1951-06-04',
          authn_context: authn_context,
          edipi: '2106798217',
          first_name: 'BRANDIN',
          last_name: 'MILLER-NIETO',
          middle_name: 'BRANSON',
          gender: 'M',
          ssn: '666016789',
          zip: nil,
          mhv_icn: '1013173963V366678',
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          uuid: '363761e8857642f7b77ef7d99200e711',
          email: 'iam.tester@example.com',
          idme_uuid: '363761e8857642f7b77ef7d99200e711',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: '2'
          },
          sec_id: '1013173963',
          participant_id: nil,
          birls_id: nil,
          icn: '1013173963V366678',
          multifactor: false,
          common_name: 'iam.tester@example.com',
          person_types: [],
          suffix: nil,
          address: {
            street: nil,
            street2: nil,
            city: nil,
            state: nil,
            country: nil,
            postal_code: nil
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: nil,
          vha_facility_hash: nil
        )
      end

      it 'does not trigger upleveling' do
        loa = subject.to_hash[:loa]
        expect((loa[:highest] > loa[:current])).to be false
      end
    end

    context 'DSLogon premium user' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level2) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1956-07-10',
          authn_context: authn_context,
          edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          zip: '20571-0001',
          mhv_icn: '1012740600V714187',
          mhv_correlation_id: '14384899',
          mhv_account_type: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: '2'
          },
          sec_id: '0000028007',
          participant_id: '600043180',
          birls_id: '796123607',
          icn: '1012740600V714187',
          multifactor: multifactor,
          common_name: 'dslogon10923109@gmail.com',
          person_types: %w[PAT VET],
          suffix: nil,
          address: {
            street: '811 Vermont Ave NW',
            street2: nil,
            city: 'Washington',
            state: 'DC',
            country: 'USA',
            postal_code: '20571-0001'
          },
          phone: '(202)555-9320',
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: %w[989 200ESR 200MHS],
          vha_facility_hash: {
            '989' => %w[552151338],
            '200ESR' => %w[0000001012740600V714187000000],
            '200MHS' => %w[14384899]
          }
        )
      end
    end

    context 'DSLogon premium user with idme uuid in gcIds' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) do
        build(:ssoe_idme_dslogon_level2,
              va_eauth_uid: ['0000028007'],
              va_eauth_csid: ['NOT_FOUND'])
      end

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1956-07-10',
          authn_context: authn_context,
          edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          zip: '20571-0001',
          mhv_icn: '1012740600V714187',
          mhv_correlation_id: '14384899',
          mhv_account_type: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: '2'
          },
          sec_id: '0000028007',
          participant_id: '600043180',
          birls_id: '796123607',
          icn: '1012740600V714187',
          multifactor: multifactor,
          common_name: 'dslogon10923109@gmail.com',
          person_types: %w[PAT VET],
          suffix: nil,
          address: {
            street: '811 Vermont Ave NW',
            street2: nil,
            city: 'Washington',
            state: 'DC',
            country: 'USA',
            postal_code: '20571-0001'
          },
          phone: '(202)555-9320',
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: %w[989 200ESR 200MHS],
          vha_facility_hash: {
            '989' => [
              '552151338'
            ],
            '200ESR' => [
              '0000001012740600V714187000000'
            ],
            '200MHS' => [
              '14384899'
            ]
          }
        )
      end
    end

    context 'DSLogon premium user without idme uuid' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) do
        build(:ssoe_idme_dslogon_level2,
              va_eauth_uid: ['NOT_FOUND'])
      end

      it 'does not validate' do
        expect { subject.validate! }.to raise_error { |error|
          expect(error).to be_a(SAML::UserAttributeError)
          expect(error.message).to eq('User attributes is missing an ID.me and Login.gov UUID')
          expect(error.identifier).to eq('1012740600V714187')
        }
      end
    end

    context 'DSLogon premium inbound user' do
      let(:authn_context) { SAML::UserAttributes::SSOe::INBOUND_AUTHN_CONTEXT }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) do
        build(:ssoe_inbound_dslogon_level2,
              va_eauth_multifactor: ['True'])
      end

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1946-10-20',
          authn_context: authn_context,
          edipi: '1606997570',
          first_name: 'SOFIA',
          last_name: 'MCKIBBENS',
          middle_name: nil,
          gender: 'F',
          ssn: '101174874',
          zip: '82009',
          mhv_icn: '1012779219V964737',
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          uuid: '85ba80dba1b93ed3bf080b2989cde313',
          email: nil,
          idme_uuid: nil,
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: 'N/A'
          },
          sec_id: '1012779219',
          participant_id: nil,
          birls_id: nil,
          icn: '1012779219V964737',
          multifactor: multifactor,
          common_name: 'SOFIA MCKIBBENS',
          person_types: [],
          suffix: nil,
          address: {
            street: '6021 WEAVER RD',
            street2: nil,
            city: 'CHEYENNE',
            state: 'WY',
            country: 'USA',
            postal_code: '82009'
          },
          phone: '(555)555-5555',
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: %w[451 969],
          vha_facility_hash: {
            '451' => %w[38401],
            '969' => %w[38401]
          }
        )
      end

      context 'with missing ID.me UUID and missing Login.gov UUID' do
        let(:saml_attributes) do
          build(:ssoe_inbound_dslogon_level2,
                va_eauth_uid: ['NOT_FOUND'])
        end
        let(:expected_log_params) { { sec_id_identifier: subject.user_attributes.uuid } }
        let(:icn) { subject.user_attributes.icn }
        let(:expected_error) { SAML::UserAttributeError }
        let(:expected_error_message) { 'User attributes is missing an ID.me and Login.gov UUID' }

        it 'raises an error during validation' do
          expect { subject.validate! }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'MHV premium inbound user' do
      let(:authn_context) { SAML::UserAttributes::SSOe::INBOUND_AUTHN_CONTEXT }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) do
        build(:ssoe_inbound_mhv_premium,
              va_eauth_multifactor: ['True'])
      end

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1982-05-23',
          authn_context: authn_context,
          edipi: nil,
          first_name: 'ZACK',
          last_name: 'DAYTMHV',
          middle_name: nil,
          gender: 'M',
          ssn: '666872589',
          zip: nil,
          mhv_icn: '1013062086V794840',
          mhv_correlation_id: '15093546',
          mhv_account_type: nil,
          uuid: '53f065475a794e14a32d707bfd9b215f',
          email: nil,
          idme_uuid: '53f065475a794e14a32d707bfd9b215f',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'N/A'
          },
          sec_id: '1013062086',
          participant_id: nil,
          birls_id: nil,
          icn: '1013062086V794840',
          multifactor: multifactor,
          common_name: 'mhvzack@mhv.va.gov',
          person_types: [],
          suffix: nil,
          address: {
            street: nil,
            street2: nil,
            city: nil,
            state: nil,
            country: nil,
            postal_code: nil
          },
          phone: nil,
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: %w[200MHS 989 200MH],
          vha_facility_hash: {
            '200MHS' => %w[15093546],
            '989' => %w[552151869],
            '200MH' => %w[15093546]
          }
        )
      end
    end

    context 'IDME LOA3 inbound user with logingov_uuid in GCIDs' do
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) do
        build(:ssoe_inbound_idme_loa3,
              va_eauth_multifactor: ['True'])
      end

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1969-04-07',
          authn_context: authn_context,
          edipi: '1320002060',
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: 'M',
          ssn: '666271152',
          zip: '10036',
          mhv_icn: '1012827134V054550',
          mhv_correlation_id: '10894456',
          mhv_account_type: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@gmail.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: 'aa478abc-e494-4ae1-8f87-d002f8fe1bbd',
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'idme',
            account_type: 'N/A'
          },
          sec_id: '1012827134',
          participant_id: '600152411',
          birls_id: '666271151',
          icn: '1012827134V054550',
          multifactor: multifactor,
          common_name: 'vets.gov.user+262@gmail.com',
          person_types: [],
          suffix: nil,
          address: {
            street: '567 W 42nd St',
            street2: nil,
            city: 'New York',
            state: 'NY',
            country: 'USA',
            postal_code: '10036'
          },
          phone: '(111)111-1111',
          cerner_id: nil,
          cerner_facility_ids: nil,
          vha_facility_ids: %w[200MHS 979 989],
          vha_facility_hash: {
            '200MHS' => %w[10894456],
            '979' => %w[943523],
            '989' => %w[552151501]
          }
        )
      end
    end
  end
end
