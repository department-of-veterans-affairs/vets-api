# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'ID.me' do
    subject { described_class.new(saml_response) }

    let(:authn_context) { LOA::IDME_LOA1_VETS }
    let(:highest_attained_loa) { '1' }
    let(:saml_attributes) { build(:idme_loa1) }
    let(:existing_saml_attributes) { nil }

    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        level_of_assurance: [highest_attained_loa],
        attributes: saml_attributes,
        existing_attributes: existing_saml_attributes
      )
    end

    context 'handles invalid authn_contexts' do
      context 'authn_context equal to something unknown' do
        let(:authn_context) { 'unknown_authn_context' }
        let(:saml_attributes) { nil }

        it 'raises expected error' do
          expect(Raven).to receive(:extra_context).once.with(
            saml_attributes: nil,
            saml_response: Base64.encode64(document_partial(authn_context).to_s)
          ).ordered
          expect(Raven).to receive(:tags_context).once.with(
            authn_context: 'unknown_authn_context',
            controller_name: 'sessions',
            sign_in_method: 'not-signed-in:error'
          )
          expect { subject.to_hash }.to raise_exception(RuntimeError)
        end
      end

      context 'authn_context equal to nil' do
        let(:authn_context) { nil }
        let(:saml_attributes) { nil }

        it 'raises expected error' do
          expect(Raven).to receive(:extra_context).once.with(
            saml_attributes: nil,
            saml_response: Base64.encode64(document_partial(authn_context).to_s)
          ).ordered
          expect(Raven).to receive(:tags_context).once.with(
            authn_context: nil,
            controller_name: 'sessions',
            sign_in_method: 'not-signed-in:error'
          )
          expect { subject.to_hash }.to raise_exception(RuntimeError)
        end
      end
    end

    context 'LOA1 user' do
      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 1 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          sec_id: nil,
          multifactor: false,
          authn_context: LOA::IDME_LOA1_VETS
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }
        let(:saml_attributes) { build(:idme_loa1, multifactor: [true]) }
        let(:existing_saml_attributes) { build(:idme_loa1, multifactor: [false]) }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            loa: { current: 1, highest: 1 },
            sign_in: { service_name: 'idme', account_type: 'N/A' },
            sec_id: nil,
            birth_date: nil,
            first_name: nil,
            last_name: nil,
            middle_name: nil,
            gender: nil,
            ssn: nil,
            zip: nil,
            multifactor: true,
            authn_context: 'multifactor'
          )
        end

        it 'is changing multifactor' do
          expect(subject).to be_changing_multifactor
        end

        context 'without an already persisted UserIdentity' do
          let(:saml_attributes) { build(:idme_loa1, multifactor: [true]) }
          let(:existing_saml_attributes) { nil }

          it 'still returns attributes defaulting LOA to 1' do
            expect_any_instance_of(SAML::User).to receive(:log_message_to_sentry).with(
              'SAML RESPONSE WARNINGS', :warn,
              authn_context: 'multifactor',
              warnings: "loa_current error: undefined method `loa' for nil:NilClass"
            )

            expect(subject.to_hash).to eq(
              uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
              email: 'kam+tristanmhv@adhocteam.us',
              idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
              loa: { current: 1, highest: 1 },
              sign_in: { service_name: 'idme', account_type: 'N/A' },
              sec_id: nil,
              birth_date: nil,
              first_name: nil,
              last_name: nil,
              middle_name: nil,
              gender: nil,
              ssn: nil,
              zip: nil,
              multifactor: true,
              authn_context: 'multifactor'
            )
          end
        end
      end
    end

    context 'LOA1 previously verified' do
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:idme_loa1, multifactor: [false], level_of_assurance: ['3']) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          sec_id: nil,
          multifactor: false,
          authn_context: LOA::IDME_LOA1_VETS
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }
        let(:saml_attributes) { build(:idme_loa1, multifactor: [true], level_of_assurance: ['3']) }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            loa: { current: 1, highest: 3 },
            sign_in: { service_name: 'idme', account_type: 'N/A' },
            sec_id: nil,
            birth_date: nil,
            first_name: nil,
            last_name: nil,
            middle_name: nil,
            gender: nil,
            ssn: nil,
            zip: nil,
            multifactor: true,
            authn_context: 'multifactor'
          )
        end

        it 'is changing multifactor' do
          expect(subject).to be_changing_multifactor
        end
      end
    end

    context 'LOA3 user' do
      let(:authn_context) { LOA::IDME_LOA3_VETS }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:idme_loa3, multifactor: [true]) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          first_name: 'Tristan',
          middle_name: '',
          last_name: 'MHV',
          gender: 'M',
          birth_date: '1735-10-30',
          ssn: '111223333',
          zip: nil,
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          sec_id: nil,
          multifactor: true,
          authn_context: LOA::IDME_LOA3_VETS
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end
  end
end
