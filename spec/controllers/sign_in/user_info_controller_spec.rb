# frozen_string_literal: true

require 'rails_helper'

describe SignIn::UserInfoController do
  let(:user_account) { create(:user_account, icn:) }
  let(:user_verification) { create(:idme_user_verification, idme_uuid: credential_uuid, user_account:) }
  let!(:user) do
    create(
      :user,
      user_account:,
      user_verification:,
      icn:,
      idme_uuid: credential_uuid,
      sec_id:,
      first_name:,
      last_name:,
      mpi_profile:
    )
  end
  let!(:client_config) { create(:client_config, client_id:) }
  let!(:session) { create(:oauth_session, client_id:, user_account:, user_verification:) }
  let!(:user_credential_email) do
    create(:user_credential_email, user_verification:, credential_email: email)
  end

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
      it 'returns the key user info fields' do
        get :show

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)

        expect(body['sub']).to eq(user.uuid)
        expect(body['email']).to eq(email)
        expect(body['first_name']).to eq(first_name)
        expect(body['last_name']).to eq(last_name)
        expect(body['full_name'].downcase).to include(first_name.downcase, last_name.downcase)
        expect(body['icn']).to eq(icn)
        expect(body['sec_id']).to eq(sec_id)
        expect(body['csp_type']).to eq('200VIDM')
        expect(body['csp_uuid']).to eq(credential_uuid)
        expect(body['ial']).to eq('2')
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
