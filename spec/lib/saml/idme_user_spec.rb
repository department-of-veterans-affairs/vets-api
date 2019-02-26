# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'ID.me' do
    let(:authn_context) { LOA::IDME_LOA1 }
    let(:account_type)  { 'N/A' }
    let(:highest_attained_loa) { '1' }

    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        account_type: account_type,
        level_of_assurance: [highest_attained_loa],
        multifactor: [false]
      )
    end
    subject { described_class.new(saml_response) }

    context 'handles invalid authn_contexts' do
      context 'no decrypted document' do
        it 'has various important attributes' do
          allow(saml_response).to receive(:decrypted_document).and_return(nil)
          expect(Raven).to receive(:extra_context).once.with(
            saml_attributes: {
              'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
              'email' => ['kam+tristanmhv@adhocteam.us'],
              'multifactor' => [false],
              'level_of_assurance' => ['1']
            },
            saml_response: Base64.encode64(document_partial(authn_context).to_s)
          )
          expect(Raven).to receive(:tags_context).once.with(
            controller_name: 'sessions', sign_in_method: 'not-signed-in:error'
          )
          expect { subject.to_hash }.to raise_exception(NoMethodError)
        end
      end

      context 'authn_context equal to something unknown' do
        let(:authn_context) { 'unknown_authn_context' }

        it 'has various important attributes' do
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

        it 'has various important attributes' do
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
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 1 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          multifactor: false,
          authn_context: LOA::IDME_LOA1
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 1, highest: 1 },
            sign_in: { service_name: 'idme', account_type: 'N/A' },
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
          expect(subject.changing_multifactor?).to be_truthy
        end

        context 'without an already persisted UserIdentity' do
          let(:build_saml_response_with_existing_user_identity?) { false }

          it 'still returns attributes defaulting LOA to 1' do
            expect_any_instance_of(SAML::User).to receive(:log_message_to_sentry).with(
              'SAML RESPONSE WARNINGS', :warn,
              authn_context: 'multifactor',
              warnings: "loa_current error: undefined method `loa' for nil:NilClass"
            )

            expect(subject.to_hash).to eq(
              uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
              email: 'kam+tristanmhv@adhocteam.us',
              loa: { current: 1, highest: 1 },
              sign_in: { service_name: 'idme', account_type: 'N/A' },
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

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          multifactor: false,
          authn_context: LOA::IDME_LOA1
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 1, highest: 3 },
            sign_in: { service_name: 'idme', account_type: 'N/A' },
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
          expect(subject.changing_multifactor?).to be_truthy
        end
      end
    end

    context 'LOA3 user' do
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:highest_attained_loa) { '3' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          first_name: 'Tristan',
          middle_name: '',
          last_name: 'MHV',
          gender: 'M',
          birth_date: '1735-10-30',
          ssn: '111223333',
          zip: nil,
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 'N/A' },
          multifactor: true,
          authn_context: LOA::IDME_LOA3
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end
    end
  end
end
