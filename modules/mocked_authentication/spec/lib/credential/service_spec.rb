# frozen_string_literal: true

require 'rails_helper'
require 'credential/service'

describe MockedAuthentication::Credential::Service do
  let(:mock_credential_instance) { described_class.new }
  let(:type) { 'some-type' }

  before { mock_credential_instance.type = type }

  describe '#render_auth' do
    subject { mock_credential_instance.render_auth(state:, acr:, operation:) }

    let(:state) { 'some-state' }
    let(:acr) { 'some-acr' }
    let(:type) { 'some-type' }
    let(:operation) { 'some-operation' }
    let(:expected_redirect_url) { IdentitySettings.sign_in.mock_auth_url }
    let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

    it 'renders the oauth_get_form template with meta refresh tag' do
      expect(subject.to_s).to include(meta_refresh_tag)
    end

    it 'renders state value' do
      expect(subject.to_s).to include(state)
    end

    it 'renders acr value' do
      expect(subject.to_s).to include(acr)
    end

    it 'renders type value' do
      expect(subject.to_s).to include(type)
    end

    it 'renders operation value' do
      expect(subject.to_s).to include(operation)
    end

    context 'when operation is not supplied' do
      let(:operation) { '' }

      it 'defaults to authorize' do
        expect(subject.to_s).to include(operation)
      end
    end

    it 'directs to the Mocked Authorization frontend page' do
      expect(subject.to_s).to include(expected_redirect_url)
    end
  end

  describe '#token' do
    subject { mock_credential_instance.token(code) }

    let(:code) { 'some-code' }

    context 'when type in mock credential service is set to logingov' do
      let(:type) { SignIn::Constants::Auth::LOGINGOV }
      let(:access_token_hash) { { access_token: code } }
      let(:encoded_credential_info) { Base64.encode64(credential_info.to_json) }
      let(:code) { 'some-code' }

      before do
        allow(SecureRandom).to receive(:hex).and_return(code)
        MockedAuthentication::CredentialInfoCreator.new(credential_info: encoded_credential_info).perform
      end

      context 'and stored logingov credential has ssn attribute' do
        let(:id_token_payload) { { logingov_acr: IAL::LOGIN_GOV_IAL2 } }
        let(:credential_info) { { social_security_number: 'some-social-security-number' } }

        it 'returns expected access token hash merged with id token hash' do
          expect(subject).to eq(access_token_hash.merge(id_token_payload))
        end
      end

      context 'and stored logingov credential does not have ssn attribute' do
        let(:id_token_payload) { { logingov_acr: IAL::LOGIN_GOV_IAL1 } }
        let(:credential_info) { { attribute: 'some-attribute' } }

        it 'returns expected access token hash merged with id token hash' do
          expect(subject).to eq(access_token_hash.merge(id_token_payload))
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
    let(:all_emails) { [email] }
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
    let(:digest) { 'some-digest' }
    let(:digester) { instance_double(SignIn::CredentialAttributesDigester) }

    before do
      allow(SignIn::CredentialAttributesDigester).to receive(:new).and_return(digester)
      allow(digester).to receive(:perform).and_return(digest)
    end

    context 'when type is equal to logingov' do
      let(:type) { SignIn::Constants::Auth::LOGINGOV }
      let(:user_info) do
        OpenStruct.new({
                         sub: user_uuid,
                         iss:,
                         email:,
                         all_emails:,
                         email_verified: true,
                         given_name: first_name,
                         family_name: last_name,
                         address:,
                         birthdate: birth_date,
                         social_security_number: ssn,
                         verified_at:
                       })
      end
      let(:verified_at) { 'some-verified-at' }
      let(:address) do
        {
          formatted: formatted_address,
          street_address: street,
          postal_code:,
          region:,
          locality:
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
          all_csp_emails: all_emails,
          multifactor:,
          authn_context:,
          auto_uplevel:,
          digest:
        }
      end
      let(:authn_context) { IAL::LOGIN_GOV_IAL2 }
      let(:expected_address) do
        {
          street: street.split("\n").first,
          street2: street.split("\n").last,
          postal_code:,
          state: region,
          city: locality,
          country:
        }
      end
      let(:expected_attributes) do
        expected_standard_attributes.merge({ ssn: ssn.tr('-', ''),
                                             birth_date:,
                                             first_name:,
                                             last_name:,
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
            iss:,
            sub: user_uuid,
            aud:,
            exp:,
            iat:,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            birth_date:,
            email:,
            street:,
            zip: postal_code,
            state: region,
            city: locality,
            phone:,
            fname: first_name,
            social: ssn,
            lname: last_name,
            level_of_assurance: 3,
            multifactor:,
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
          street:,
          postal_code:,
          state: region,
          city: locality,
          country:
        }
      end
      let(:expected_attributes) do
        {
          idme_uuid: user_uuid,
          current_ial: IAL::TWO,
          max_ial: IAL::TWO,
          service_name: type,
          csp_email: email,
          all_csp_emails: nil,
          multifactor:,
          authn_context:,
          auto_uplevel:,
          ssn: ssn.tr('-', ''),
          birth_date:,
          first_name:,
          last_name:,
          address: expected_address,
          digest:
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
            aud:,
            exp:,
            iat:,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            email:,
            mhv_uuid: mhv_credential_uuid,
            mhv_icn:,
            mhv_assurance:,
            level_of_assurance: 3,
            multifactor:,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:mhv_credential_uuid) { 'some-mhv-credential-uuid' }
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
          all_csp_emails: nil,
          multifactor:,
          authn_context:,
          auto_uplevel:,
          mhv_icn:,
          mhv_credential_uuid:,
          mhv_assurance:,
          digest:
        }
      end

      it 'returns expected attributes' do
        expect(subject).to eq(expected_attributes)
      end
    end
  end
end
