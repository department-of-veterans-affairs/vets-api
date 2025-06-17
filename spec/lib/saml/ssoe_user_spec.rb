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
        authn_context:,
        level_of_assurance: [highest_attained_loa],
        attributes: saml_attributes,
        existing_attributes: existing_saml_attributes,
        in_response_to: login_uuid,
        issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
      )
    end
    let(:sign_in) do
      {
        service_name:,
        account_type:,
        auth_broker:,
        client_id:
      }
    end
    let(:service_name) { 'logingov' }
    let(:account_type) { 'N/A' }
    let(:auth_broker) { SAML::URLService::BROKER_CODE }
    let(:client_id) { 'vaweb' }

    before do
      SAMLRequestTracker.create(
        uuid: login_uuid,
        payload: {
          application: client_id
        }
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
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          ssn: nil,
          birth_date: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          idme_uuid: nil,
          logingov_uuid: '54e78de6140d473f87960f211be49c08',
          verified_at: nil,
          sec_id: nil,
          mhv_icn: nil,
          mhv_credential_uuid: nil,
          mhv_account_type: nil,
          edipi: nil,
          loa: { current: 1, highest: 1 },
          sign_in:,
          multifactor: true,
          icn: nil,
          authn_context:
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
          middle_name: 'LOGIN',
          gender: 'M',
          ssn: '123123123',
          mhv_icn: '1200049153V217987',
          mhv_credential_uuid: '123456',
          mhv_account_type: nil,
          edipi: nil,
          uuid: 'aa478abc-e494-4af1-9f87-d002f8fe1cda',
          email: 'vets.gov.user+1000@example.com',
          idme_uuid: nil,
          logingov_uuid: 'aa478abc-e494-4af1-9f87-d002f8fe1cda',
          verified_at: '2021-10-28T23:54:46Z',
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1200049153',
          icn: '1200049153V217987',
          multifactor: true,
          authn_context:
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
      let(:service_name) { 'idme' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context:,
          birth_date: nil,
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: nil,
          ssn: nil,
          mhv_icn: nil,
          mhv_credential_uuid: nil,
          mhv_account_type: nil,
          edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: nil,
          verified_at: nil,
          multifactor: false,
          loa: { current: 1, highest: 1 },
          sign_in:,
          sec_id: nil,
          icn: nil
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'previously proofed IDme LOA1 user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1) }
      let(:service_name) { 'idme' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context:,
          birth_date: nil,
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: nil,
          ssn: nil,
          mhv_icn: nil,
          mhv_credential_uuid: nil,
          mhv_account_type: nil,
          edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: nil,
          verified_at: nil,
          multifactor: true,
          loa: { current: 1, highest: 3 },
          sign_in:,
          sec_id: nil,
          icn: nil
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'IDme LOA3 user' do
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:saml_attributes) { build(:ssoe_idme_loa3) }
      let(:service_name) { 'idme' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context:,
          birth_date: '1969-04-07',
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: 'M',
          ssn: '666271152',
          mhv_icn: '1008830476V316605',
          mhv_credential_uuid: nil,
          mhv_account_type: nil,
          edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: nil,
          verified_at: nil,
          multifactor: true,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1008830476',
          icn: '1008830476V316605'
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
      let(:service_name) { 'mhv' }
      let(:account_type) { 'Advanced' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context:,
          edipi: nil,
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          mhv_icn: nil,
          mhv_credential_uuid: nil,
          mhv_account_type: 'Advanced',
          uuid: '881571066e5741439652bc80759dd88c',
          email: 'alexmac_0@example.com',
          idme_uuid: '881571066e5741439652bc80759dd88c',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 1, highest: 3 },
          sign_in:,
          sec_id: nil,
          icn: nil,
          multifactor:
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
      let(:service_name) { 'mhv' }
      let(:account_type) { 'Advanced' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1988-11-24',
          authn_context:,
          edipi: nil,
          first_name: 'ALEX',
          last_name: 'MAC',
          middle_name: nil,
          gender: 'F',
          ssn: '230595111',
          mhv_icn: '1013183292V131165',
          mhv_credential_uuid: '15001594',
          mhv_account_type: 'Advanced',
          uuid: '881571066e5741439652bc80759dd88c',
          email: 'alexmac_0@example.com',
          idme_uuid: '881571066e5741439652bc80759dd88c',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1013183292',
          icn: '1013183292V131165',
          multifactor:
        )
      end
    end

    context 'MHV non premium user who adds multifactor' do
      let(:authn_context) { 'myhealthevet_multifactor' }
      let(:highest_attained_loa) { '1' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_basic_multifactor) }
      let(:multifactor) { false }
      let(:existing_saml_attributes) { build(:ssoe_idme_mhv_basic_singlefactor) }
      let(:service_name) { 'mhv' }
      let(:account_type) { 'Basic' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context:,
          edipi: nil,
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          mhv_icn: nil,
          mhv_credential_uuid: nil,
          mhv_account_type: 'Basic',
          uuid: '72782a87a807407f83e8a052d804d7f7',
          email: 'pv+mhvtestb@example.com',
          idme_uuid: '72782a87a807407f83e8a052d804d7f7',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 1, highest: 1 },
          sign_in:,
          sec_id: nil,
          icn: nil,
          multifactor: true
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
      let(:service_name) { 'mhv' }
      let(:account_type) { 'Premium' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1977-03-07',
          authn_context:,
          edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          mhv_icn: '1012853550V207686',
          mhv_credential_uuid: '12345748',
          mhv_account_type: 'Premium',
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'k+tristanmhv@example.com',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1012853550',
          icn: '1012853550V207686',
          multifactor:
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
      let(:service_name) { 'mhv' }
      let(:account_type) { 'Premium' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1977-03-07',
          authn_context:,
          edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          mhv_icn: '1012853550V207686',
          mhv_credential_uuid: '12345748',
          mhv_account_type: 'Premium',
          uuid: nil,
          email: 'k+tristanmhv@example.com',
          idme_uuid: nil,
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1012853550',
          icn: nil,
          multifactor:
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
            mhv_credential_uuid: '999888'
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
            mhv_credential_uuid: mhv_ien
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
            mhv_credential_uuid: mhv_ien
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with multiple mhv id values identifiers' do
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
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}" }

        it 'resolves mhv id from credential provider' do
          expect(subject.to_hash).to include(
            mhv_credential_uuid: mhv_uuid
          )
        end

        context 'normal validation flow' do
          it 'logs a warning and doesnt raise an error' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'MHV outbound-redirect flow' do
          let(:client_id) { 'mhv' }

          it 'logs a warning and doesnt raise an error' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
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
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}" }

        context 'normal validation flow' do
          it 'does not validate' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
            expect { subject.validate! }.to raise_error { |error|
              expect(error).to be_a(SAML::UserAttributeError)
              expect(error.message).to eq(expected_error_message)
            }
          end
        end

        context 'MHV outbound-redirect flow' do
          let(:client_id) { 'myvahealth' }

          it 'does not validate and logs a Sentry warning' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
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
              mhv_credential_uuid: '888777'
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
              mhv_credential_uuid: '888777'
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
              mhv_credential_uuid: nil
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
              mhv_credential_uuid: '888777'
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
          let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}" }

          it 'logs a warning but does not raise an error' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'with mis-matching active mhvien values from gcids' do
          let(:uuid) { 'NOT_FOUND' }
          let(:first_ien) { '999888' }
          let(:second_ien) { '888777' }
          let(:expected_error) { SAML::UserAttributeError::ERRORS[:multiple_mhv_ids] }
          let(:expected_error_data) { { mismatched_ids: [first_ien, second_ien], icn: mhv_icn } }
          let(:expected_error_message) { expected_error[:message] }
          let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}" }

          it 'logs a warning but does not raise an error' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
            expect { subject.validate! }.not_to raise_error
          end
        end
      end
    end

    context 'with multi-value sec_id string' do
      let(:saml_attributes) do
        build(:ssoe_idme_mhv_loa3, va_eauth_secid: [sec_id])
      end

      context 'with one id string' do
        let(:sec_id) { '1234567890' }

        it 'does not log a warning to sentry' do
          expect_any_instance_of(SentryLogging).not_to receive(:log_message_to_sentry).with(
            'User attributes contains multiple sec_id values',
            'warn',
            { sec_id: }
          )
          subject.validate!
        end
      end

      context 'with two ids string' do
        let(:sec_id) { '1234567890,0987654321' }

        it 'logs a warning to sentry' do
          expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
            'User attributes contains multiple sec_id values',
            'warn',
            { sec_id: }
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
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}" }

        context 'regular auth flow' do
          it 'does not validate and prevents login' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
            expect { subject.validate! }
              .to raise_error { |error|
                    expect(error).to be_a(SAML::UserAttributeError)
                    expect(error.message).to eq(expected_error_message)
                  }
          end
        end

        context 'MHV outbound-redirect flow' do
          let(:client_id) { 'mhv' }

          it 'logs a Sentry warning and allows login' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'incorrect outbound-redirect flow' do
          let(:client_id) { 'test application' }

          it 'does not validate and prevents login' do
            expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
            expect { subject.validate! }
              .to raise_error { |error|
                    expect(error).to be_a(SAML::UserAttributeError)
                    expect(error.message).to eq(expected_error_message)
                  }
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
        let(:expected_log) { "[SAML::UserAttributes::SSOe] #{expected_error_message}" }

        it 'does not validate' do
          expect(Rails.logger).to receive(:warn).with(expected_log, expected_error_data)
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
      let(:service_name) { 'dslogon' }
      let(:account_type) { '1' }

      it 'has various important attributes', skip: 'Unknown reason for skip' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context:,
          edipi: '1606997570',
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          mhv_icn: nil,
          mhv_credential_uuid: nil,
          mhv_account_type: nil,
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 1, highest: 3 },
          sign_in:,
          sec_id: nil,
          icn: nil,
          multifactor:
        )
      end
    end

    context 'DSLogon premium user without multifactor' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) do
        build(:ssoe_idme_dslogon_level2_singlefactor,
              va_eauth_gcIds: ['1013173963V366678^NI^200M^USVHA^P|' \
                               '2106798217^NI^200DOD^USDOD^A' \
                               '363761e8857642f7b77ef7d99200e711^PN^200VIDM^USDVA^A|' \
                               '2106798217^NI^200DOD^USDOD^A|' \
                               '1013173963^PN^200PROV^USDVA^A'])
      end
      let(:service_name) { 'dslogon' }
      let(:account_type) { '2' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1951-06-04',
          authn_context:,
          edipi: '2106798217',
          first_name: 'BRANDIN',
          last_name: 'MILLER-NIETO',
          middle_name: 'BRANSON',
          gender: 'M',
          ssn: '666016789',
          mhv_icn: '1013173963V366678',
          mhv_credential_uuid: nil,
          mhv_account_type: nil,
          uuid: '363761e8857642f7b77ef7d99200e711',
          email: 'iam.tester@example.com',
          idme_uuid: '363761e8857642f7b77ef7d99200e711',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1013173963',
          icn: '1013173963V366678',
          multifactor: false
        )
      end

      it 'does not trigger upleveling' do
        loa = subject.to_hash[:loa]
        expect(loa[:highest] > loa[:current]).to be false
      end
    end

    context 'DSLogon premium user' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level2) }
      let(:service_name) { 'dslogon' }
      let(:account_type) { '2' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1956-07-10',
          authn_context:,
          edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          mhv_icn: '1012740600V714187',
          mhv_credential_uuid: '14384899',
          mhv_account_type: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '0000028007',
          icn: '1012740600V714187',
          multifactor:
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
      let(:service_name) { 'dslogon' }
      let(:account_type) { '2' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1956-07-10',
          authn_context:,
          edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          mhv_icn: '1012740600V714187',
          mhv_credential_uuid: '14384899',
          mhv_account_type: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '0000028007',
          icn: '1012740600V714187',
          multifactor:
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
      let(:service_name) { 'dslogon' }
      let(:account_type) { 'N/A' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1946-10-20',
          authn_context:,
          edipi: '1606997570',
          first_name: 'SOFIA',
          last_name: 'MCKIBBENS',
          middle_name: nil,
          gender: 'F',
          ssn: '101174874',
          mhv_icn: '1012779219V964737',
          mhv_credential_uuid: nil,
          mhv_account_type: nil,
          uuid: nil,
          email: nil,
          idme_uuid: nil,
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1012779219',
          icn: '1012779219V964737',
          multifactor:
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
      let(:service_name) { 'mhv' }
      let(:account_type) { 'N/A' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1982-05-23',
          authn_context:,
          edipi: nil,
          first_name: 'ZACK',
          last_name: 'DAYTMHV',
          middle_name: nil,
          gender: 'M',
          ssn: '666872589',
          mhv_icn: '1013062086V794840',
          mhv_credential_uuid: '15093546',
          mhv_account_type: nil,
          uuid: '53f065475a794e14a32d707bfd9b215f',
          email: nil,
          idme_uuid: '53f065475a794e14a32d707bfd9b215f',
          logingov_uuid: nil,
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1013062086',
          icn: '1013062086V794840',
          multifactor:
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
      let(:service_name) { 'idme' }
      let(:account_type) { 'N/A' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1969-04-07',
          authn_context:,
          edipi: '1320002060',
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: 'M',
          ssn: '666271152',
          mhv_icn: '1012827134V054550',
          mhv_credential_uuid: '10894456',
          mhv_account_type: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@gmail.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          logingov_uuid: 'aa478abc-e494-4ae1-8f87-d002f8fe1bbd',
          verified_at: nil,
          loa: { current: 3, highest: 3 },
          sign_in:,
          sec_id: '1012827134',
          icn: '1012827134V054550',
          multifactor:
        )
      end
    end
  end
end
