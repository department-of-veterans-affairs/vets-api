# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenidApplicationController, type: :controller do
  let(:token) { okta_jwt(%w[profile email openid va_profile]) }
  let(:payload) { token[0] }
  let(:iss) { token[0]['iss'] }
  let(:kid) { token[1]['kid'] }
  let(:alg) { token[1]['alg'] }

  def change_encoded_token_payload(options = {}, new_kid = kid)
    new_payload = payload.merge(options)
    @encoded_token = JWT.encode(new_payload, @public_key, alg, 'kid' => new_kid)
    request.headers['Authorization'] = "Bearer #{@encoded_token}"
  end

  describe '#permit_scopes' do
    context 'with simple scopes' do
      before do
        @public_key ||= OpenSSL::PKey::RSA.generate(2048)

        @encoded_token = JWT.encode(payload, @public_key, alg, 'kid' => kid)
        request.headers['Authorization'] = "Bearer #{@encoded_token}"

        allow(OIDC::KeyService).to receive(:get_key).with(anything, anything).and_return(nil)
        allow(OIDC::KeyService).to receive(:get_key).with(kid, iss).and_return(@public_key)
      end

      controller do
        before_action { permit_scopes 'profile' }

        def index
          render json: { 'test' => 'Secret Info.' }
        end
      end

      it 'permits access when token has allowed scopes' do
        with_okta_profile_configured do
          get :index
          expect(response).to be_ok
        end
      end

      it 'rejects access when the token does not have the allowed scopes' do
        with_okta_configured do
          change_encoded_token_payload('scp' => ['bad_scope'])
          get :index
          expect(response.status).to eq(401)
        end
      end

      it 'rejects access when the public key is not found' do
        with_okta_configured do
          change_encoded_token_payload({}, 'bad kid value')
          get :index
          expect(response.status).to eq(401)
          errors = JSON.parse(response.body)['errors']
          expect(errors[0]['detail']).to eq("Public key not found for kid specified in token: 'bad kid value'")
        end
      end

      it 'rejects access when expired' do
        with_okta_configured do
          exp_token_opts = {
            'iat' => Time.current.utc.to_i - 7200,
            'exp' => Time.current.utc.to_i - 3600
          }
          change_encoded_token_payload(exp_token_opts)

          get :index

          expect(response.status).to eq(401)
          errors = JSON.parse(response.body)['errors']
          expect(errors[0]['detail']).to eq('Signature has expired')
        end
      end

      it 'logs expired token' do
        with_okta_configured do
          exp_token_opts = {
            'iat' => Time.current.utc.to_i - 7200,
            'exp' => Time.current.utc.to_i - 3600
          }
          change_encoded_token_payload(exp_token_opts)
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger).to receive(:info).with('Signature has expired', token: @encoded_token)
          get :index
        end
      end
    end

    context 'with complex scopes' do
      controller do
        before_action { permit_scopes 'profile', actions: :index }
        before_action { permit_scopes 'openid', actions: %i[show update] }
        before_action { permit_scopes %w[email openid], actions: %i[destroy] }

        %i[index show update destroy].each do |method|
          define_method method do
            render json: { 'test' => 'Secret Info.' }
          end
        end
      end

      before do
        @public_key ||= OpenSSL::PKey::RSA.generate(2048)

        @encoded_token = JWT.encode(payload, @public_key, alg, 'kid' => kid)
        request.headers['Authorization'] = "Bearer #{@encoded_token}"

        allow(OIDC::KeyService).to receive(:get_key).with(kid, iss).and_return(@public_key)
      end

      it 'permits access to one action with the correct scope' do
        with_okta_profile_configured do
          get :index
          expect(response).to be_ok
        end
      end

      it 'rejects access to one action without the correct scope' do
        with_okta_configured do
          token_opts = { 'scp' => %w[openid] }
          change_encoded_token_payload(token_opts)

          get :index
          expect(response.status).to eq(401)
        end
      end

      it 'permits access if at least one of the allowed scopes is provided' do
        with_okta_profile_configured do
          token_opts = { 'scp' => %w[email] }
          change_encoded_token_payload(token_opts)

          delete :destroy, params: { id: 1 }
          expect(response).to be_ok
        end
      end

      it 'permits access if all the allowed scopes are provided' do
        with_okta_profile_configured do
          token_opts = { 'scp' => %w[email openid] }
          change_encoded_token_payload(token_opts)

          delete :destroy, params: { id: 1 }
          expect(response).to be_ok
        end
      end

      it 'rejects access if none of the allowed scopes are provided' do
        with_okta_configured do
          token_opts = { 'scp' => %w[profile va_profile] }
          change_encoded_token_payload(token_opts)

          delete :destroy, params: { id: 1 }
          expect(response.status).to eq(401)
        end
      end
    end
  end

  describe '#authenticate' do
    controller do
      def index
        render json: {
          'test' => 'It worked.',
          'user' => @current_user.email,
          'icn' => @current_user.icn,
          'last_name' => @current_user.last_name,
          'loa_current' => @current_user.loa[:current]
        }
      end
    end

    context 'with no jwt supplied' do
      it 'returns 401' do
        get :index
        expect(response.status).to eq(401)
      end
    end

    context 'with a valid jwt supplied and no session' do
      before do
        allow(JWT).to receive(:decode).and_return(token)
      end

      it 'returns 200 and add the user to the session' do
        with_okta_profile_configured do
          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('2407c3c16aec54ccecd91078128ebab4007bb5252ef0e947ba3a2418bdc86ee1')).not_to be_nil
          expect(JSON.parse(response.body)['user']).to eq('vets.gov.user+20@gmail.com')
        end
      end

      it 'returns 200 and add the ssoi user to the session' do
        with_ssoi_profile_configured do
          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          sesh = Session.find('2407c3c16aec54ccecd91078128ebab4007bb5252ef0e947ba3a2418bdc86ee1')
          expect(sesh.profile).not_to be_nil
          expect(sesh.token).not_to be_nil
          expect(sesh.uuid).not_to be_nil
        end
      end
    end

    context 'with an opaque token supplied and no session' do
      it 'returns 401' do
        request.headers['Authorization'] = 'Bearer FakeToken'
        get :index
        expect(response.status).to eq(401)
        errors = JSON.parse(response.body)['errors']
        expect(errors[0]['detail']).to eq('Invalid token.')
      end
    end

    context 'with a MHV credential profile' do
      let(:mpi_profile) do
        build(:mpi_profile,
              icn: '1013062086V794840',
              family_name: 'zackariah')
      end

      before do
        allow(JWT).to receive(:decode).and_return(token)
        stub_mpi(mpi_profile)
      end

      let(:okta_response) { FactoryBot.build(:okta_mhv_response) }
      let(:faraday_response) { instance_double('Faraday::Response') }

      it 'returns 200 and add user to session' do
        with_okta_configured do
          allow_any_instance_of(Okta::Service).to receive(:user).and_return(faraday_response)
          allow(faraday_response).to receive(:success?).and_return(true)
          allow(faraday_response).to receive(:body).and_return(okta_response)

          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('2407c3c16aec54ccecd91078128ebab4007bb5252ef0e947ba3a2418bdc86ee1')).not_to be_nil
          expect(JSON.parse(response.body)['user']).to eq('mhvzack_0@example.com')
          expect(JSON.parse(response.body)['icn']).to eq('1013062086V794840')
          expect(JSON.parse(response.body)['last_name']).to eq('zackariah')
          expect(JSON.parse(response.body)['loa_current']).to eq(3)
        end
      end
    end

    context 'with a DSLogon credential profile' do
      let(:okta_response) { FactoryBot.build(:okta_dslogon_response) }
      let(:faraday_response) { instance_double('Faraday::Response') }
      let(:mpi_profile) do
        build(:mpi_profile,
              icn: '1013062086V794840',
              family_name: 'WEAVER')
      end

      before do
        allow(JWT).to receive(:decode).and_return(token)
        stub_mpi(mpi_profile)
      end

      it 'returns 200 and add user to session' do
        with_okta_configured do
          allow_any_instance_of(Okta::Service).to receive(:user).and_return(faraday_response)
          allow(faraday_response).to receive(:success?).and_return(true)
          allow(faraday_response).to receive(:body).and_return(okta_response)

          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('2407c3c16aec54ccecd91078128ebab4007bb5252ef0e947ba3a2418bdc86ee1')).not_to be_nil
          expect(JSON.parse(response.body)['user']).to eq('dslogon10923109@example.com')
          expect(JSON.parse(response.body)['icn']).to eq('1013062086V794840')
          expect(JSON.parse(response.body)['last_name']).to eq('WEAVER')
          expect(JSON.parse(response.body)['loa_current']).to eq(3)
        end
      end
    end

    context 'with an ID.me credential profile' do
      let(:okta_response) { FactoryBot.build(:okta_idme_response) }
      let(:faraday_response) { instance_double('Faraday::Response') }
      let(:mpi_profile) do
        build(:mpi_profile,
              icn: '1013062086V794840',
              family_name: 'CARROLL')
      end

      before do
        allow(JWT).to receive(:decode).and_return(token)
        stub_mpi(mpi_profile)
      end

      it 'returns 200 and add user to session' do
        with_okta_configured do
          allow_any_instance_of(Okta::Service).to receive(:user).and_return(faraday_response)
          allow(faraday_response).to receive(:success?).and_return(true)
          allow(faraday_response).to receive(:body).and_return(okta_response)

          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('2407c3c16aec54ccecd91078128ebab4007bb5252ef0e947ba3a2418bdc86ee1')).not_to be_nil
          expect(JSON.parse(response.body)['user']).to eq('vets.gov.user+20@gmail.com')
          expect(JSON.parse(response.body)['icn']).to eq('1013062086V794840')
          expect(JSON.parse(response.body)['last_name']).to eq('CARROLL')
          expect(JSON.parse(response.body)['loa_current']).to eq(3)
        end
      end
    end
  end
end
