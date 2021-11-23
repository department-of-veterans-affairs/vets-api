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

      it 'raises a validation error' do
        expect { UserSessionForm.new(saml_response) }.to raise_error { |error|
          expect(error).to be_a(SAML::UserAttributeError)
        }
      end

      it 'instantiates if a unique account mapping exists' do
        create(:account, icn: saml_attributes[:va_eauth_icn])
        UserSessionForm.new(saml_response)
      end

      it 'raises a validation error ands logs a message if multiple account mappings exist' do
        create(:account, icn: icn)
        create(:account, icn: icn)

        expect(Rails.logger).to receive(:info).with(expected_log_message)

        expect { UserSessionForm.new(saml_response) }.to raise_error { |error|
          expect(error).to be_a(SAML::UserAttributeError)
        }
      end

      it 'uses the injected identifier as the user key' do
        account = create(:account, icn: saml_attributes[:va_eauth_icn])
        subject = UserSessionForm.new(saml_response)
        subject.persist
        expect(User.find(account.idme_uuid)).to be_truthy
        expect(UserIdentity.find(account.idme_uuid)).to be_truthy
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
