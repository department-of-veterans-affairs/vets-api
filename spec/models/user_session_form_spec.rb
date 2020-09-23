# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe UserSessionForm, type: :model do
  include SAML::ResponseBuilder

  # subject { described_class.new(saml_response) }

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
  end

  context 'with ID.me UUID not present in SAML' do
    let(:saml_attributes) do
      build(:ssoe_inbound_mhv_premium, va_eauth_gcIds: [''])
    end

    it 'raises a validation error' do
      expect { UserSessionForm.new(saml_response) }.to raise_error { |error|
        expect(error).to be_a(SAML::UserAttributeError)
      }
    end

    it 'instantiates if a unique account mapping exists' do
      create(:account, icn: saml_attributes[:va_eauth_icn])
      UserSessionForm.new(saml_response)
    end

    it 'raises a validation error if multiple account mappings exist' do
      create(:account, icn: saml_attributes[:va_eauth_icn])
      create(:account, icn: saml_attributes[:va_eauth_icn])

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
end
