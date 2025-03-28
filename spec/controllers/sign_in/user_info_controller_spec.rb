# frozen_string_literal: true

require 'rails_helper'

describe SignIn::UserInfoController do
  let!(:client_config) { create(:client_config, client_id:) }
  let!(:session) { create(:oauth_session, client_id:) }
  let!(:user_credential_email) do
    create(:user_credential_email, user_verification: session.user_verification, credential_email: email)
  end

  let!(:user) { create(:user, uuid: credential_uuid, idme_uuid: credential_uuid, mpi_profile:) }
  let(:mpi_profile) { build(:mpi_profile, icn:, sec_id:, given_names: [first_name], family_name: last_name) }

  let(:credential_uuid) { 'some-uuid' }
  let(:icn) { 'some-icn' }
  let(:sec_id) { 'some-sec-id' }
  let(:first_name) { 'some-first-name' }
  let(:last_name) { 'some-last-name' }
  let(:email) { 'some-email' }
  let(:client_id) { 'some-client-id' }
  let(:user_info_clients) { [client_id] }

  let(:access_token) { create(:access_token, user_uuid: user.uuid, client_id:, session_handle: session.handle) }
  let(:encoded_access_token) { SignIn::AccessTokenJwtEncoder.new(access_token:).perform }

  before do
    allow(IdentitySettings.sign_in).to receive(:user_info_clients).and_return(user_info_clients)
    request.headers['Authorization'] = "Bearer #{encoded_access_token}"
  end

  describe 'GET #show' do
    context 'when the client_id is in the list of valid clients' do
      let(:expected_user_info_json) do
        {
          sub: credential_uuid,
          credential_uuid:,
          icn:,
          sec_id:,
          first_name:,
          last_name:,
          email:
        }
      end

      it 'returns the user info' do
        get :show
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(expected_user_info_json.to_json)
      end
    end

    context 'when the client_id is not in the list of valid clients' do
      let(:user_info_clients) { ['some-other-client-id'] }

      it 'returns a forbidden response' do
        get :show
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
