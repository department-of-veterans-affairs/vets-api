# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe InheritedProofingController, type: :controller do
  describe 'GET auth' do
    subject { get(:auth) }

    context 'when user is not authenticated' do
      let(:expected_error_title) { 'Not authorized' }

      it 'returns an unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end

      it 'renders not authorized error' do
        expect(JSON.parse(subject.body)['errors'].first['title']).to eq(expected_error_title)
      end
    end

    context 'when user is authenticated' do
      let(:icn) { '1013459302V141714' }
      let(:correlation_id) { '19031408' }
      let(:identity_info_url) { "#{Settings.mhv.inherited_proofing.base_path}/mhvacctinfo/#{correlation_id}" }
      let(:current_user) do
        build(:user, :mhv,
              mhv_icn: icn,
              mhv_correlation_id: correlation_id)
      end

      before { sign_in_as(current_user) }

      context 'and user is MHV eligible' do
        let(:identity_data_response) do
          {
            'mhvId' => 19031205, # rubocop:disable Style/NumericLiterals
            'identityProofedMethod' => 'IPA',
            'identityProofingDate' => '2020-12-14',
            'identityDocumentExist' => true,
            'identityDocumentInfo' => {
              'primaryIdentityDocumentNumber' => '73929233',
              'primaryIdentityDocumentType' => 'StateIssuedId',
              'primaryIdentityDocumentCountry' => 'United States',
              'primaryIdentityDocumentExpirationDate' => '2026-03-30'
            }
          }
        end
        let(:auth_code) { SecureRandom.hex }

        before do
          stub_request(:get, identity_info_url).to_return(
            body: identity_data_response.to_json
          )
          allow(SecureRandom).to receive(:hex).and_return(auth_code)
        end

        it 'renders Login.gov OAuth form with the MHV verifier auth_code' do
          expect(subject.body).to include("id=\"inherited_proofing_auth\" value=\"#{auth_code}\"")
        end

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end
      end

      context 'and user is not MHV eligible' do
        let(:identity_data_failed_response) do
          {
            'mhvId' => 9712240, # rubocop:disable Style/NumericLiterals
            'identityDocumentExist' => false
          }
        end
        let(:expected_error) { InheritedProofing::Errors::IdentityDocumentMissingError.to_s }
        let(:expected_error_json) { { 'errors' => expected_error } }

        before do
          stub_request(:get, identity_info_url).to_return(
            body: identity_data_failed_response.to_json
          )
        end

        it 'renders identity document missing error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns a bad request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end
    end
  end

  describe 'GET user_attributes' do
    subject { get(:user_attributes) }

    context 'when authorization header does not exist' do
      let(:authorization_header) { nil }
      let(:expected_error) { InheritedProofing::Errors::AccessTokenMalformedJWTError.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders Malformed JWT error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when authorization header exists' do
      let(:authorization) { "Bearer #{access_token_jwt}" }
      let(:private_key) { OpenSSL::PKey::RSA.new(512) }
      let(:public_key) { private_key.public_key }
      let(:access_token_jwt) do
        JWT.encode(payload, private_key, InheritedProofing::JwtDecoder::JWT_ENCODE_ALGORITHM)
      end
      let(:payload) { { inherited_proofing_auth: auth_code, exp: expiration_time.to_i } }
      let(:expiration_time) { Time.zone.now + 5.minutes }
      let(:auth_code) { 'some-auth-code' }

      before do
        request.headers['Authorization'] = authorization
        allow_any_instance_of(InheritedProofing::JwtDecoder).to receive(:public_key).and_return(public_key)
      end

      context 'and access_token is some arbitrary value' do
        let(:access_token_jwt) { 'some-arbitrary-access-token' }
        let(:expected_error) { InheritedProofing::Errors::AccessTokenMalformedJWTError.to_s }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Malformed Params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and access_token is an expired JWT' do
        let(:expiration_time) { Time.zone.now - 1.day }
        let(:expected_error) { InheritedProofing::Errors::AccessTokenExpiredError.to_s }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders access token expired error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and access_token is an active JWT' do
        context 'and access_token payload does not have an inherited proofing auth field' do
          let(:payload) { { exp: expiration_time.to_i } }
          let(:expected_error) { InheritedProofing::Errors::AccessTokenMissingRequiredAttributesError.to_s }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders access token missing required attributes error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns unauthorized status' do
            expect(subject).to have_http_status(:unauthorized)
          end
        end

        context 'and access_token has an inherited proofing auth field' do
          let(:payload) { { inherited_proofing_auth: auth_code, exp: expiration_time.to_i } }

          context 'and there is not a mhv identity data object for the given auth code in the access token' do
            let(:expected_error) { InheritedProofing::Errors::MHVIdentityDataNotFoundError.to_s }
            let(:expected_error_json) { { 'errors' => expected_error } }

            it 'renders mhv identity data not found error' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end

            it 'returns bad request status' do
              expect(subject).to have_http_status(:bad_request)
            end
          end

          context 'and there is a mhv identity data object for the given auth code in the access token' do
            let!(:mhv_identity_data) { create(:mhv_identity_data, code: auth_code, user_uuid: user.uuid) }
            let(:user) { create(:user, :mhv) }

            before do
              allow_any_instance_of(InheritedProofing::UserAttributesEncryptor)
                .to receive(:public_key).and_return(public_key)
            end

            it 'renders expected encrypted user attributes' do
              encrypted_user_attributes = JSON.parse(subject.body)['data']
              decrypted_user_attributes = JWE.decrypt(encrypted_user_attributes, private_key)
              parsed_user_attributes = JSON.parse(decrypted_user_attributes)

              expect(parsed_user_attributes['first_name']).to eq(user.first_name)
              expect(parsed_user_attributes['last_name']).to eq(user.last_name)
              expect(parsed_user_attributes['address']).to eq(user.address.with_indifferent_access)
              expect(parsed_user_attributes['mhv_data']).to eq(mhv_identity_data.data.with_indifferent_access)
              expect(parsed_user_attributes['phone']).to eq(user.home_phone)
              expect(parsed_user_attributes['birth_date']).to eq(user.birth_date)
              expect(parsed_user_attributes['ssn']).to eq(user.ssn)
            end

            it 'returns ok status' do
              expect(subject).to have_http_status(:ok)
            end
          end
        end
      end
    end
  end

  describe 'GET callback' do
    subject { get :callback, params: { auth_code: auth_code } }

    let(:audit_data_auth_code) { SecureRandom.hex }
    let(:auth_code) { audit_data_auth_code }
    let(:audit_data_user) { create(:user, :mhv, uuid: SecureRandom.uuid) }
    let(:current_user) { audit_data_user }
    let!(:audit_data) { create(:audit_data, user_uuid: audit_data_user.uuid, code: audit_data_auth_code) }

    context 'when user is not authenticated' do
      let(:expected_error_title) { 'Not authorized' }

      it 'returns an unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end

      it 'renders not authorized error' do
        expect(JSON.parse(subject.body)['errors'].first['title']).to eq(expected_error_title)
      end
    end

    context 'when user is authenticated' do
      let(:icn) { '1013459302V141714' }
      let(:correlation_id) { '19031408' }
      let(:identity_info_url) { "#{Settings.mhv.inherited_proofing.base_path}/mhvacctinfo/#{correlation_id}" }
      let!(:user_verification) { create(:mhv_user_verification, mhv_uuid: current_user.mhv_correlation_id) }
      let(:user_account) { current_user.user_account }

      before do
        sign_in_as(current_user)
      end

      context 'audit_data validations' do
        shared_examples 'audit_data validation cleanup' do
          it 'destroys the audit_data record' do
            expect(InheritedProofing::AuditData.find(auth_code)).not_to be(nil)
            subject
            expect(InheritedProofing::AuditData.find(auth_code)).to be(nil)
          end
        end

        context 'failed validations' do
          let(:expected_error_json) { { 'errors' => expected_error } }

          context 'when auth_code is not present' do
            let(:auth_code) { nil }
            let(:expected_error) { InheritedProofing::Errors::AuthCodeMissingError.to_s }

            it 'renders an AuthCodeMissingError' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end
          end

          context 'when audit_data is not found' do
            let(:auth_code) { SecureRandom.hex }
            let(:expected_error) { InheritedProofing::Errors::AuthCodeInvalidError.to_s }

            it 'renders an AuthCodeInvalidError' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end
          end

          context 'when the current user does not match the audit_data user' do
            let(:current_user) { create(:user, :mhv) }
            let(:expected_error) { InheritedProofing::Errors::InvalidUserError.to_s }

            it 'renders an InvalidUserError' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end

            it_behaves_like 'audit_data validation cleanup'
          end

          context 'when the current user\'s sign_in service_name does not match audit_data legacy_csp' do
            let(:current_user) { create(:user, :dslogon, uuid: audit_data_user.uuid) }
            let(:expected_error) { InheritedProofing::Errors::InvalidCSPError.to_s }

            it 'renders an InvalidCSPError' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end

            it_behaves_like 'audit_data validation cleanup'
          end
        end

        context 'successful validation' do
          it 'passes audit_data validations and calls for inhertited proofing verification' do
            expect_any_instance_of(InheritedProofingController).to receive(:save_inherited_proofing_verification)
            expect(subject).to have_http_status(:redirect)
          end

          it_behaves_like 'audit_data validation cleanup'
        end
      end

      context 'and user has not already verified in the past' do
        let(:expected_redirect_url) do
          url_for(controller: 'v1/sessions', action: :new, type: SAML::User::LOGINGOV_CSID)
        end

        it 'saves an inherited proofing verification attached to the expected user account' do
          expect { subject }.to change(InheritedProofVerifiedUserAccount, :count).from(0).to(1)
          expect(InheritedProofVerifiedUserAccount.find_by(user_account: user_account)).not_to be(nil)
        end

        it 'resets the current session' do
          expect { subject }.to change { User.find(current_user.uuid) }.to(nil)
        end

        it 'redirects to v1/sessions controller for a new logingov authentication' do
          expect(subject).to redirect_to(expected_redirect_url)
        end

        it 'returns redirect status' do
          expect(subject).to have_http_status(:redirect)
        end
      end

      context 'and user had already verified in the past' do
        let!(:verified_inherifed_proof) do
          create(:inherited_proof_verified_user_account, user_account: current_user.user_account)
        end
        let(:expected_error) { InheritedProofing::Errors::PreviouslyVerifiedError.to_s }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders previously verified error error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns a bad request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end
    end
  end
end
