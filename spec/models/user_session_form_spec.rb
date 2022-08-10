# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe UserSessionForm, type: :model do
  include SAML::ResponseBuilder

  let(:loa3_user) do
    build(:user, :loa3, uuid: saml_attributes[:uuid],
                        idme_uuid: saml_attributes[:uuid])
  end
  let(:saml_response) do
    build_saml_response(
      authn_context: 'myhealthevet',
      level_of_assurance: '3',
      attributes: saml_attributes,
      existing_attributes: nil,
      issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
    )
  end

  context 'with ID.me UUID in SAML' do
    let(:saml_attributes) do
      build(:ssoe_idme_mhv_premium)
    end

    it 'instantiates cleanly' do
      UserSessionForm.new(saml_response)
    end

    it 'instantiates with a Session SSOe transactionid' do
      form = UserSessionForm.new(saml_response)
      expect(form.session[:ssoe_transactionid])
        .to eq(saml_attributes['va_eauth_transactionid'])
    end

    it 'instantiates with an expected id.me UUID' do
      form = UserSessionForm.new(saml_response)
      expect(form.user_identity.idme_uuid)
        .to eq(saml_attributes['va_eauth_uid'])
    end
  end

  context 'with ID.me UUID not present in SAML' do
    context 'and Login.gov UUID is not present in SAML' do
      let(:saml_attributes) do
        build(:ssoe_inbound_mhv_premium, va_eauth_gcIds: [''])
      end
      let(:icn) { saml_attributes[:va_eauth_icn] }
      let(:expected_log_message) { "[UserSessionForm] Multiple matching accounts for icn:#{icn}" }
      let!(:account) { create(:account, icn: icn) }

      context 'and there are no existing account mappings for the user' do
        let(:account) { nil }
        let(:expected_error) { SAML::UserAttributeError }

        it 'raises a saml user attribute error' do
          expect { UserSessionForm.new(saml_response) }.to raise_error(SAML::UserAttributeError)
        end
      end

      context 'when multiple account mappings exist' do
        let!(:second_account) { create(:account, icn: icn) }

        it 'raises a validation error ands logs a message' do
          expect(Rails.logger).to receive(:info).with(expected_log_message)

          expect { UserSessionForm.new(saml_response) }.to raise_error(SAML::UserAttributeError)
        end
      end

      context 'when credential identifier can be found on existing account' do
        let!(:account) { create(:account, icn: saml_attributes[:va_eauth_icn]) }
        let(:add_person_response) do
          MPI::Responses::AddPersonResponse.new(status: status, mvi_codes: mvi_codes, error: nil)
        end
        let(:status) { 'OK' }
        let(:mvi_codes) { { icn: saml_attributes[:va_eauth_icn] } }

        before do
          allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(add_person_response)
        end

        it 'uses the injected identifier as the user key' do
          subject = UserSessionForm.new(saml_response)
          subject.persist
          expect(User.find(account.idme_uuid)).to be_truthy
          expect(UserIdentity.find(account.idme_uuid)).to be_truthy
        end

        it 'adds the identifier to an existing mpi record' do
          expect_any_instance_of(MPI::Service).to receive(:add_person_implicit_search)
          UserSessionForm.new(saml_response)
        end

        context 'when failure occurs during adding identifier to existing mpi record' do
          let(:status) { 'some-not-successful-status' }
          let(:idme_uuid) { account.idme_uuid }
          let(:logingov_uuid) { account.logingov_uuid }
          let(:sentry_log) { "Failed Add CSP ID to MPI FAILED, idme: #{idme_uuid}, logingov: #{logingov_uuid}" }
          let(:sentry_level) { :warn }

          it 'logs a message to sentry' do
            expect_any_instance_of(UserSessionForm).to receive(:log_message_to_sentry).with(sentry_log, sentry_level)
            UserSessionForm.new(saml_response)
          end
        end
      end
    end

    context 'and Login.gov UUID is present in SAML' do
      let(:saml_attributes) do
        build(:ssoe_logingov_ial2)
      end

      it 'instantiates cleanly' do
        UserSessionForm.new(saml_response)
      end

      it 'instantiates with a Session SSOe transactionid' do
        form = UserSessionForm.new(saml_response)
        expect(form.session[:ssoe_transactionid])
          .to eq(saml_attributes['va_eauth_transactionid'])
      end

      it 'instantiates with an expected login.gov UUID' do
        form = UserSessionForm.new(saml_response)
        expect(form.user_identity.logingov_uuid)
          .to eq(saml_attributes['va_eauth_uid'])
      end
    end
  end
end
