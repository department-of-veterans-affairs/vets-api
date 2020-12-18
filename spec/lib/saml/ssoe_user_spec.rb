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
    let(:callback_url) { 'http://http://127.0.0.1:3000/v1/sessions/callback/v1/sessions/callback' }
    let(:rubysaml_settings) { build(:rubysaml_settings_v1, assertion_consumer_service_url: callback_url) }

    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        level_of_assurance: [highest_attained_loa],
        attributes: saml_attributes,
        existing_attributes: existing_saml_attributes,
        issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20',
        settings: rubysaml_settings
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
          dslogon_edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          multifactor: false,
          loa: { current: 1, highest: 1 },
          sign_in: {
            service_name: 'idme',
            account_type: 'N/A'
          },
          sec_id: nil,
          participant_id: nil,
          birls_id: nil,
          common_name: nil
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
          dslogon_edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          multifactor: true,
          loa: { current: 1, highest: 3 },
          sign_in: {
            service_name: 'idme',
            account_type: 'N/A'
          },
          sec_id: nil,
          participant_id: nil,
          birls_id: nil,
          common_name: nil
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
          gender: 'M',
          ssn: '666271152',
          zip: nil,
          mhv_icn: '1008830476V316605',
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          dslogon_edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          multifactor: true,
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          sec_id: '1008830476',
          participant_id: nil,
          birls_id: nil,
          common_name: 'vets.gov.user+262@example.com'
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
          dslogon_edipi: nil,
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
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Advanced' },
          sec_id: nil,
          participant_id: nil,
          birls_id: nil,
          multifactor: multifactor,
          common_name: nil
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
          dslogon_edipi: nil,
          first_name: 'ALEX',
          last_name: 'MAC',
          middle_name: nil,
          gender: 'F',
          ssn: '230595111',
          zip: nil,
          mhv_icn: '1013183292V131165',
          mhv_correlation_id: '15001594',
          mhv_account_type: 'Advanced',
          uuid: '881571066e5741439652bc80759dd88c',
          email: 'alexmac_0@example.com',
          idme_uuid: '881571066e5741439652bc80759dd88c',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Advanced' },
          sec_id: '1013183292',
          participant_id: nil,
          birls_id: nil,
          multifactor: multifactor,
          common_name: 'alexmac_0@example.com'
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
          dslogon_edipi: nil,
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
          loa: { current: 1, highest: 1 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'Basic'
          },
          sec_id: nil,
          birls_id: nil,
          participant_id: nil,
          multifactor: true,
          common_name: nil
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
          dslogon_edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          zip: nil,
          mhv_icn: '1012853550V207686',
          mhv_correlation_id: '12345748',
          mhv_account_type: 'Premium',
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'k+tristanmhv@example.com',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'Premium'
          },
          sec_id: '1012853550',
          participant_id: nil,
          birls_id: nil,
          multifactor: multifactor,
          common_name: 'k+tristan@example.com'
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
              va_eauth_gcIds: [''])
      end
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1977-03-07',
          authn_context: authn_context,
          dslogon_edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          zip: nil,
          mhv_icn: '1012853550V207686',
          mhv_correlation_id: '12345748',
          mhv_account_type: 'Premium',
          uuid: Digest::UUID.uuid_v3('sec-id', '1012853550').tr('-', ''),
          email: 'k+tristanmhv@example.com',
          idme_uuid: nil,
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'Premium'
          },
          sec_id: '1012853550',
          participant_id: nil,
          birls_id: nil,
          multifactor: multifactor,
          common_name: 'k+tristan@example.com'
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
                va_eauth_mhvien: ['NOT_FOUND'])
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
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: ['NOT_FOUND'],
                va_eauth_mhvien: ['888777'])
        end

        it 'resolves mhv id' do
          expect(subject.to_hash).to include(
            mhv_correlation_id: '888777'
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with matching identifiers' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: ['888777'],
                va_eauth_mhvien: ['888777'])
        end

        it 'resolves mhv id' do
          expect(subject.to_hash).to include(
            mhv_correlation_id: '888777'
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with mismatching identifiers' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: ['999888'],
                va_eauth_mhvien: ['888777'])
        end

        it 'resolves mhv id from credential provider' do
          expect(subject.to_hash).to include(
            mhv_correlation_id: '999888'
          )
        end

        it 'does not validate' do
          expect { subject.validate! }.to raise_error { |error|
            expect(error).to be_a(SAML::UserAttributeError)
            expect(error.message).to eq('User attributes contain multiple distinct MHV ID values')
          }
        end
      end

      context 'with mismatching ICNs' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvicn: ['111111111V666666'],
                va_eauth_icn: ['22222222V888888'])
        end

        it 'does not validate' do
          expect { subject.validate! }.to raise_error { |error|
            expect(error).to be_a(SAML::UserAttributeError)
            expect(error.message).to eq('MHV credential ICN does not match MPI record')
          }
        end
      end

      context 'with multi-value mhvien' do
        let(:saml_attributes) do
          build(:ssoe_idme_mhv_loa3,
                va_eauth_mhvuuid: [uuid],
                va_eauth_mhvien: [ien])
        end

        context 'with matching values' do
          let(:uuid) { 'NOT_FOUND' }
          let(:ien) { '888777,888777' }

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
          let(:ien) { 'NOT_FOUND' }

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
          let(:ien) { 'NOT_FOUND' }

          it 'de-duplicates values' do
            expect(subject.to_hash).to include(
              mhv_correlation_id: nil
            )
          end

          it 'validates' do
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'with matching mhvien and mhvuuid' do
          let(:uuid) { '888777' }
          let(:ien) { '888777,888777' }

          it 'de-duplicates values' do
            expect(subject.to_hash).to include(
              mhv_correlation_id: '888777'
            )
          end

          it 'validates' do
            expect { subject.validate! }.not_to raise_error
          end
        end

        context 'with mis-matching mhvien and mhvuuid' do
          let(:uuid) { '888777' }
          let(:ien) { '888777,999888' }

          let(:saml_attributes) do
            build(:ssoe_idme_mhv_loa3,
                  va_eauth_mhvuuid: ['888777'],
                  va_eauth_mhvien: ['999888,888777'])
          end

          it 'does not validate' do
            expect { subject.validate! }
              .to raise_error { |error|
                    expect(error).to be_a(SAML::UserAttributeError)
                    expect(error.message).to eq('User attributes contain multiple distinct MHV ID values')
                  }
          end
        end

        context 'with mis-matching mhvien values' do
          let(:uuid) { 'NOT_FOUND' }
          let(:ien) { '999888,888777' }

          it 'does not validate' do
            expect { subject.validate! }
              .to raise_error { |error|
                    expect(error).to be_a(SAML::UserAttributeError)
                    expect(error.message).to eq('User attributes contain multiple distinct MHV ID values')
                  }
          end
        end
      end
    end

    context 'with multi-value edipi' do
      let(:saml_attributes) do
        build(:ssoe_idme_mhv_loa3,
              va_eauth_dodedipnid: [edipi])
      end

      context 'with different values' do
        let(:edipi) { '0123456789,0000000054' }

        it 'does not validate' do
          expect { subject.validate! }
            .to raise_error { |error|
                  expect(error).to be_a(SAML::UserAttributeError)
                  expect(error.message).to eq('User attributes contain multiple distinct EDIPI values')
                }
        end
      end

      context 'with matching values' do
        let(:edipi) { '0123456789,0123456789' }

        it 'de-duplicates values' do
          expect(subject.to_hash).to include(
            dslogon_edipi: '0123456789'
          )
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'with empty value' do
        let(:edipi) { 'NOT_FOUND' }

        it 'de-duplicates values' do
          expect(subject.to_hash).to include(
            dslogon_edipi: nil
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
          dslogon_edipi: '1606997570',
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
          multifactor: multifactor
        )
      end
    end

    context 'DSLogon premium user without multifactor' do
      let(:authn_context) { 'dslogon' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level2_singlefactor) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1951-06-04',
          authn_context: authn_context,
          dslogon_edipi: '2106798217',
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
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: '2'
          },
          sec_id: '1013173963',
          participant_id: nil,
          birls_id: nil,
          multifactor: false,
          common_name: 'iam.tester@example.com'
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
          dslogon_edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          zip: '20571-0001',
          mhv_icn: '1012740600V714187',
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: '2'
          },
          sec_id: '0000028007',
          participant_id: '600043180',
          birls_id: '796123607',
          multifactor: multifactor,
          common_name: 'dslogon10923109@gmail.com'
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
          dslogon_edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          zip: '20571-0001',
          mhv_icn: '1012740600V714187',
          mhv_correlation_id: nil,
          mhv_account_type: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: '2'
          },
          sec_id: '0000028007',
          participant_id: '600043180',
          birls_id: '796123607',
          multifactor: multifactor,
          common_name: 'dslogon10923109@gmail.com'
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
          expect(error.message).to eq('User attributes is missing an ID.me UUID')
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
          dslogon_edipi: '1606997570',
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
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'dslogon',
            account_type: 'N/A'
          },
          sec_id: '1012779219',
          participant_id: nil,
          birls_id: nil,
          multifactor: multifactor,
          common_name: 'SOFIA MCKIBBENS'
        )
      end

      context 'with missing ID.me UUID' do
        let(:saml_attributes) do
          build(:ssoe_inbound_dslogon_level2,
                va_eauth_uid: ['NOT_FOUND'])
        end

        it 'validates' do
          expect { subject.validate! }.not_to raise_error
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
          dslogon_edipi: nil,
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
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'myhealthevet',
            account_type: 'N/A'
          },
          sec_id: '1013062086',
          participant_id: nil,
          birls_id: nil,
          multifactor: multifactor,
          common_name: 'mhvzack@mhv.va.gov'
        )
      end
    end

    context 'IDME LOA3 inbound user' do
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
          dslogon_edipi: '1320002060',
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: 'M',
          ssn: '666271152',
          zip: nil,
          mhv_icn: '1012827134V054550',
          mhv_correlation_id: '10894456',
          mhv_account_type: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@gmail.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          loa: { current: 3, highest: 3 },
          sign_in: {
            service_name: 'idme',
            account_type: 'N/A'
          },
          sec_id: '1012827134',
          participant_id: '600152411',
          birls_id: '666271151',
          multifactor: multifactor,
          common_name: 'vets.gov.user+262@gmail.com'
        )
      end
    end
  end
end
