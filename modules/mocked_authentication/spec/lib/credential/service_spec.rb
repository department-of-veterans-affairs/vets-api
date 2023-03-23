# frozen_string_literal: true

require 'rails_helper'
require 'credential/service'

describe MockedAuthentication::Credential::Service do
  let(:mock_credential_instance) { described_class.new }
  let(:type) { 'some-type' }

  before { mock_credential_instance.type = type }

  describe '#render_auth' do
    subject { mock_credential_instance.render_auth(state: state, acr: acr) }

    let(:state) { 'some-state' }
    let(:acr) { 'some-acr' }
    let(:expected_redirect_url) { Settings.sign_in.mock_auth_url }

    it 'renders the oauth_get_form template' do
      expect(subject.to_s).to include('form id="oauth-form"')
    end

    it 'renders state value' do
      expect(subject.to_s).to include("value=\"#{state}\"")
    end

    it 'renders acr value' do
      expect(subject.to_s).to include("value=\"#{acr}\"")
    end

    it 'directs to the Mocked Authorization frontend page' do
      expect(subject.to_s).to include("action=\"#{expected_redirect_url}\"")
    end
  end

  describe '#token' do
    subject { mock_credential_instance.token(code) }

    let(:code) { 'some-code' }

    context 'when type in mock credential service is set to logingov' do
      let(:type) { SignIn::Constants::Auth::LOGINGOV }
      let(:access_token_hash) { { access_token: code } }
      let(:id_token_hash) { { id_token: id_token } }
      let(:id_token) { JWT.encode(id_token_payload, nil) }
      let(:encoded_credential_info) { Base64.encode64(credential_info.to_json) }
      let(:code) { 'some-code' }

      before do
        allow(SecureRandom).to receive(:hex).and_return(code)
        MockedAuthentication::CredentialInfoCreator.new(credential_info: encoded_credential_info).perform
      end

      context 'and stored logingov credential has ssn attribute' do
        let(:id_token_payload) { { acr: IAL::LOGIN_GOV_IAL2 } }
        let(:credential_info) { { social_security_number: 'some-social-security-number' } }

        it 'returns expected access token hash merged with id token hash' do
          expect(subject).to eq(access_token_hash.merge(id_token_hash))
        end
      end

      context 'and stored logingov credential does not have ssn attribute' do
        let(:id_token_payload) { { acr: IAL::LOGIN_GOV_IAL1 } }
        let(:credential_info) { { attribute: 'some-attribute' } }

        it 'returns expected access token hash merged with id token hash' do
          expect(subject).to eq(access_token_hash.merge(id_token_hash))
        end
      end
    end

    context 'when type in mock credential service is not set to logingov' do
      let(:type) { 'some-type' }
      let(:expected_access_token_hash) { { access_token: code } }

      it 'returns expected access token hash' do
        expect(subject).to eq(expected_access_token_hash)
      end
    end
  end

  describe '#user_info' do
    subject { mock_credential_instance.user_info(token) }

    let(:token) { mock_credential_info.credential_info_code }
    let(:mock_credential_info) { create(:mock_credential_info) }
    let(:expected_credential_info) { OpenStruct.new(mock_credential_info.credential_info) }

    it 'returns credential info from expected CredentialInfo object' do
      expect(subject).to eq(expected_credential_info)
    end
  end

  describe '#normalized_attributes' do
    subject { mock_credential_instance.normalized_attributes(user_info, credential_level) }

    let(:user_info) { 'some-user-info' }
    let(:first_name) { 'some-first-name' }
    let(:middle_name) { 'some-middle-name' }
    let(:last_name) { 'some-last-name' }
    let(:birth_date) { 'some-birth-date' }
    let(:ssn) { 'some-ssn' }
    let(:email) { 'some-email' }
    let(:user_uuid) { 'some-user-uuid' }
    let(:street) { "some-street\nsome-second-line-street" }
    let(:postal_code) { 'some-postal-code' }
    let(:region) { 'some-region' }
    let(:locality) { 'some-locality' }
    let(:iss) { 'some-iss' }
    let(:multifactor) { true }
    let(:credential_level) { create(:credential_level, current_ial: IAL::TWO, max_ial: IAL::TWO) }
    let(:auto_uplevel) { false }
    let(:country) { 'USA' }
    let(:phone) { 'some-phone' }

    context 'when type is equal to logingov' do
      let(:type) { SignIn::Constants::Auth::LOGINGOV }
      let(:user_info) do
        OpenStruct.new({
                         sub: user_uuid,
                         iss: iss,
                         email: email,
                         email_verified: true,
                         given_name: first_name,
                         family_name: last_name,
                         address: address,
                         birthdate: birth_date,
                         social_security_number: ssn,
                         verified_at: verified_at
                       })
      end
      let(:verified_at) { 'some-verified-at' }
      let(:address) do
        {
          formatted: formatted_address,
          street_address: street,
          postal_code: postal_code,
          region: region,
          locality: locality
        }
      end
      let(:formatted_address) { "#{street}\n#{locality}, #{region} #{postal_code}" }
      let(:expected_standard_attributes) do
        {
          logingov_uuid: user_uuid,
          current_ial: IAL::TWO,
          max_ial: IAL::TWO,
          service_name: type,
          csp_email: email,
          multifactor: multifactor,
          authn_context: authn_context,
          auto_uplevel: auto_uplevel
        }
      end
      let(:authn_context) { IAL::LOGIN_GOV_IAL2 }
      let(:expected_address) do
        {
          street: street.split("\n").first,
          street2: street.split("\n").last,
          postal_code: postal_code,
          state: region,
          city: locality,
          country: country
        }
      end
      let(:expected_attributes) do
        expected_standard_attributes.merge({ ssn: ssn.tr('-', ''),
                                             birth_date: birth_date,
                                             first_name: first_name,
                                             last_name: last_name,
                                             address: expected_address })
      end

      it 'returns expected attributes' do
        expect(subject).to eq(expected_attributes)
      end
    end

    context 'when type is equal to idme' do
      let(:type) { SignIn::Constants::Auth::IDME }
      let(:user_info) do
        OpenStruct.new(
          {
            iss: iss,
            sub: user_uuid,
            aud: aud,
            exp: exp,
            iat: iat,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            birth_date: birth_date,
            email: email,
            street: street,
            zip: postal_code,
            state: region,
            city: locality,
            phone: phone,
            fname: first_name,
            social: ssn,
            lname: last_name,
            level_of_assurance: 3,
            multifactor: multifactor,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:aud) { 'some-aud' }
      let(:exp) { 'some-exp' }
      let(:iat) { 'some-iat' }
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:expected_address) do
        {
          street: street,
          postal_code: postal_code,
          state: region,
          city: locality,
          country: country
        }
      end
      let(:expected_attributes) do
        {
          idme_uuid: user_uuid,
          current_ial: IAL::TWO,
          max_ial: IAL::TWO,
          service_name: type,
          csp_email: email,
          multifactor: multifactor,
          authn_context: authn_context,
          auto_uplevel: auto_uplevel,
          ssn: ssn.tr('-', ''),
          birth_date: birth_date,
          first_name: first_name,
          last_name: last_name,
          address: expected_address
        }
      end

      it 'returns expected attributes' do
        expect(subject).to eq(expected_attributes)
      end
    end

    context 'when type is equal to dslogon' do
      let(:type) { SignIn::Constants::Auth::DSLOGON }
      let(:user_info) do
        OpenStruct.new(
          {
            iss: user_uuid,
            sub: user_uuid,
            aud: aud,
            exp: exp,
            iat: iat,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            dslogon_birth_date: birth_date,
            email: email,
            dslogon_uuid: edipi,
            dslogon_fname: first_name,
            dslogon_idvalue: ssn,
            dslogon_lname: last_name,
            dslogon_mname: middle_name,
            level_of_assurance: 3,
            multifactor: multifactor,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:edipi) { 'some-edipi' }
      let(:aud) { 'some-aud' }
      let(:exp) { 'some-exp' }
      let(:iat) { 'some-iat' }
      let(:authn_context) { LOA::IDME_DSLOGON_LOA3 }
      let(:expected_attributes) do
        {
          idme_uuid: user_uuid,
          current_ial: IAL::TWO,
          max_ial: IAL::TWO,
          service_name: type,
          csp_email: email,
          multifactor: multifactor,
          authn_context: authn_context,
          auto_uplevel: auto_uplevel,
          ssn: ssn.tr('-', ''),
          birth_date: birth_date,
          first_name: first_name,
          middle_name: middle_name,
          last_name: last_name,
          edipi: edipi
        }
      end

      it 'returns expected attributes' do
        expect(subject).to eq(expected_attributes)
      end
    end

    context 'when type is equal to mhv' do
      let(:type) { SignIn::Constants::Auth::MHV }
      let(:user_info) do
        OpenStruct.new(
          {
            iss: user_uuid,
            sub: user_uuid,
            aud: aud,
            exp: exp,
            iat: iat,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            email: email,
            mhv_uuid: mhv_correlation_id,
            mhv_icn: mhv_icn,
            mhv_assurance: mhv_assurance,
            level_of_assurance: 3,
            multifactor: multifactor,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:mhv_correlation_id) { 'some-mhv-correlation-id' }
      let(:mhv_icn) { 'some-mhv-icn' }
      let(:mhv_assurance) { 'some-mhv-assurance' }
      let(:aud) { 'some-aud' }
      let(:exp) { 'some-exp' }
      let(:iat) { 'some-iat' }
      let(:authn_context) { LOA::IDME_MHV_LOA3 }
      let(:expected_attributes) do
        {
          idme_uuid: user_uuid,
          current_ial: IAL::TWO,
          max_ial: IAL::TWO,
          service_name: type,
          csp_email: email,
          multifactor: multifactor,
          authn_context: authn_context,
          auto_uplevel: auto_uplevel,
          mhv_icn: mhv_icn,
          mhv_correlation_id: mhv_correlation_id,
          mhv_assurance: mhv_assurance
        }
      end

      it 'returns expected attributes' do
        expect(subject).to eq(expected_attributes)
      end
    end
  end
end
