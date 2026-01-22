# frozen_string_literal: true

require 'rails_helper'

describe SignIn::UserInfoController do
  let!(:client_config) { create(:client_config, client_id:) }
  let(:client_id) { 'some-client-id' }
  let(:user_info_clients) { [client_id] }
  let!(:session) { create(:oauth_session, client_id:, user_account:, user_verification:) }

  let(:user_account) { create(:user_account, icn:) }
  let(:user_verification) { create(:idme_user_verification, idme_uuid: credential_uuid, user_account:) }
  let(:mpi_profile) do
    build(:mpi_profile, icn:, address:, home_phone:, full_mvi_ids: gcids)
  end

  let(:user) do
    build(
      :user,
      :loa3,
      user_account:,
      user_verification:,
      icn:,
      idme_uuid: credential_uuid,
      first_name: mpi_profile.given_names.first,
      last_name: mpi_profile.family_name,
      birth_date: mpi_profile.birth_date,
      ssn: mpi_profile.ssn,
      gender: mpi_profile.gender,
      edipi: mpi_profile.edipi,
      sec_id: mpi_profile.sec_id,
      mpi_profile:
    )
  end
  let(:credential_uuid) { 'some-uuid' }
  let(:icn) { 'some-icn' }

  let(:home_phone) { '555-123-4567' }
  let(:gcids) do
    [
      '1000123456V123456^NI^200M^USVHA^P',
      '12345^PI^516^USVHA^PCE',
      '2^PI^553^USVHA^PCE'
    ]
  end

  let(:address) do
    {
      street: '123 Main St',
      street2: 'Apt 4B',
      city: 'Somecity',
      state: 'CA',
      country: 'USA',
      postal_code: '90210'
    }
  end

  let!(:user_credential_email) { create(:user_credential_email, user_verification:, credential_email:) }
  let(:credential_email) { 'test@example.com' }

  let(:access_token) { create(:access_token, user_uuid: user.uuid, client_id:, session_handle: session.handle) }
  let(:encoded_access_token) { SignIn::AccessTokenJwtEncoder.new(access_token:).perform }

  before do
    allow(IdentitySettings.sign_in).to receive(:user_info_clients).and_return(user_info_clients)
    request.headers['Authorization'] = "Bearer #{encoded_access_token}"
  end

  describe 'GET #show' do
    context 'when the client_id is in the list of valid clients' do
      context 'when the user has valid attributes' do
        it 'returns the key user info fields' do
          get :show

          expect(response).to have_http_status(:ok)

          body = JSON.parse(response.body)
          expect(body['sub']).to eq(credential_uuid)
          expect(body['ial']).to eq(SignIn::Constants::Auth::IAL_TWO.to_s)
          expect(body['aal']).to eq('http://idmanagement.gov/ns/assurance/aal/2')
          expect(body['csp_type']).to eq(MPI::Constants::IDME_IDENTIFIER)
          expect(body['csp_uuid']).to eq(credential_uuid)
          expect(body['email']).to eq(credential_email)
          expect(body['first_name']).to eq(user.first_name)
          expect(body['last_name']).to eq(user.last_name)
          expect(body['full_name']).to eq(user.full_name_normalized.values.compact.join(' '))
          expect(body['birth_date']).to eq(user.birth_date)
          expect(body['ssn']).to eq(user.ssn)
          expect(body['gender']).to eq(user.gender)
          expect(body['address_street1']).to eq(user.address[:street])
          expect(body['address_street2']).to eq(user.address[:street2])
          expect(body['address_city']).to eq(user.address[:city])
          expect(body['address_state']).to eq(user.address[:state])
          expect(body['address_country']).to eq(user.address[:country])
          expect(body['address_postal_code']).to eq(user.address[:postal_code])
          expect(body['phone_number']).to eq(user.home_phone)
          expect(body['person_types']).to eq(user.person_types.join('|'))
          expect(body['icn']).to eq(user.icn)
          expect(body['edipi']).to eq(user.edipi)
          expect(body['mhv_ien']).to eq(user.mhv_ien)
          expect(body['sec_id']).to eq(user.sec_id)
          expect(body['cerner_id']).to eq(user.cerner_id)
          expect(body['corp_id']).to eq(user.participant_id)
          expect(body['birls']).to eq(user.birls_id)
          expect(body['gcids']).to eq(gcids.join('|'))
        end
      end

      context 'when the user_info is invalid' do
        before do
          allow_any_instance_of(SignIn::UserInfo).to receive(:valid?).and_return(false)
        end

        it 'returns a bad request' do
          get :show

          expect(response).to have_http_status(:bad_request)
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
end
