# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenidApplicationController, type: :controller do
  let(:token) do
    [{
      'ver' => 1,
      'jti' => 'AT.04f_GBSkMkWYbLgG5joGNlApqUthsZnYXhiyPc_5KZ0',
      'iss' => 'https://example.com/oauth2/default',
      'aud' => 'api://default',
      'iat' => Time.current.utc.to_i,
      'exp' => Time.current.utc.to_i + 3600,
      'cid' => '0oa1c01m77heEXUZt2p7',
      'uid' => '00u1zlqhuo3yLa2Xs2p7',
      'scp' => %w[profile email openid va_profile],
      'sub' => 'ae9ff5f4e4b741389904087d94cd19b2'
    }, {
      'kid' => '1Z0tNc4Hxs_n7ySgwb6YT8JgWpq0wezqupEg136FZHU',
      'alg' => 'RS256'
    }]
  end

  describe '#permit_scopes' do
    before(:each) do
      request.headers['Authorization'] = 'Bearer FakeToken'
    end

    context 'with simple scopes' do
      controller do
        before_action { permit_scopes 'profile' }

        def index
          render json: { 'test' => 'Secret Info.' }
        end
      end

      it 'should permit access when token has allowed scopes' do
        with_okta_configured do
          allow(JWT).to receive(:decode).and_return(token)
          get :index
          expect(response).to be_ok
        end
      end

      it 'should reject access when the does not have the allowed scopes' do
        with_okta_configured do
          new_token = token
          new_token[0]['scp'] = ['bad_scope']
          allow(JWT).to receive(:decode).and_return(new_token)
          get :index
          expect(response.status).to eq(401)
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

      it 'should permit access to one action with the correct scope' do
        with_okta_configured do
          allow(JWT).to receive(:decode).and_return(token)
          get :index
          expect(response).to be_ok
        end
      end

      it 'should reject access to one action without the correct scope' do
        with_okta_configured do
          new_token = token
          new_token[0]['scp'] = %w[openid]
          allow(JWT).to receive(:decode).and_return(new_token)
          get :index
          expect(response.status).to eq(401)
        end
      end

      it 'should permit access to all actions when the correct scope is provided' do
        with_okta_configured do
          new_token = token
          new_token[0]['scp'] = %w[openid]
          allow(JWT).to receive(:decode).and_return(new_token)
          get :show, id: 1
          expect(response).to be_ok
          patch :update, id: 1
          expect(response).to be_ok
        end
      end

      it 'should reject access to all actions when the incorrect scope is provided' do
        with_okta_configured do
          new_token = token
          new_token[0]['scp'] = %w[profile]
          allow(JWT).to receive(:decode).and_return(new_token)
          get :show, id: 1
          expect(response.status).to eq(401)
          patch :update, id: 1
          expect(response.status).to eq(401)
        end
      end

      it 'should permit access if at least one of the allowed scopes is provided' do
        with_okta_configured do
          new_token = token
          new_token[0]['scp'] = %w[email]
          allow(JWT).to receive(:decode).and_return(new_token)
          delete :destroy, id: 1
          expect(response).to be_ok
        end
      end

      it 'should permit access if all the allowed scopes are provided' do
        with_okta_configured do
          new_token = token
          new_token[0]['scp'] = %w[email openid]
          allow(JWT).to receive(:decode).and_return(new_token)
          delete :destroy, id: 1
          expect(response).to be_ok
        end
      end

      it 'should reject access if none of the allowed scopes are provided' do
        with_okta_configured do
          new_token = token
          new_token[0]['scp'] = %w[profile va_profile]
          allow(JWT).to receive(:decode).and_return(new_token)
          delete :destroy, id: 1
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
      it 'should return 401' do
        get :index
        expect(response.status).to eq(401)
      end
    end

    context 'with a valid jwt supplied and no session' do
      before(:each) do
        allow(JWT).to receive(:decode).and_return(token)
      end

      it 'should return 200 and add the user to the session' do
        with_okta_configured do
          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('FakeToken')).to_not be_nil
          expect(JSON.parse(response.body)['user']).to eq('vets.gov.user+20@gmail.com')
        end
      end
    end

    context 'with a MHV credential profile' do
      let(:mvi_profile) do
        build(:mvi_profile,
              icn: '10000012345V123457',
              family_name: 'zackariah')
      end

      before(:each) do
        allow(JWT).to receive(:decode).and_return(token)
        stub_mvi(mvi_profile)
      end

      let(:okta_response) { FactoryBot.build(:okta_mhv_response) }
      let(:faraday_response) { instance_double('Faraday::Response') }

      it 'should return 200 and add user to session' do
        with_okta_configured do
          Okta::Service.any_instance.stub(:user).and_return(faraday_response)
          allow(faraday_response).to receive(:success?).and_return(true)
          allow(faraday_response).to receive(:body).and_return(okta_response)

          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('FakeToken')).to_not be_nil
          expect(JSON.parse(response.body)['user']).to eq('mhvzack_0@example.com')
          expect(JSON.parse(response.body)['icn']).to eq('10000012345V123457')
          expect(JSON.parse(response.body)['last_name']).to eq('zackariah')
          expect(JSON.parse(response.body)['loa_current']).to eq(3)
        end
      end
    end

    context 'with a DSLogon credential profile' do
      let(:okta_response) { FactoryBot.build(:okta_dslogon_response) }
      let(:faraday_response) { instance_double('Faraday::Response') }
      let(:mvi_profile) do
        build(:mvi_profile,
              icn: '10000012345V123456',
              family_name: 'WEAVER')
      end

      before(:each) do
        allow(JWT).to receive(:decode).and_return(token)
        stub_mvi(mvi_profile)
      end

      it 'should return 200 and add user to session' do
        with_okta_configured do
          Okta::Service.any_instance.stub(:user).and_return(faraday_response)
          allow(faraday_response).to receive(:success?).and_return(true)
          allow(faraday_response).to receive(:body).and_return(okta_response)

          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('FakeToken')).to_not be_nil
          expect(JSON.parse(response.body)['user']).to eq('dslogon10923109@example.com')
          expect(JSON.parse(response.body)['icn']).to eq('10000012345V123456')
          expect(JSON.parse(response.body)['last_name']).to eq('WEAVER')
          expect(JSON.parse(response.body)['loa_current']).to eq(3)
        end
      end
    end

    context 'with an ID.me credential profile' do
      let(:okta_response) { FactoryBot.build(:okta_idme_response) }
      let(:faraday_response) { instance_double('Faraday::Response') }
      let(:mvi_profile) do
        build(:mvi_profile,
              icn: '10000012345V123458',
              family_name: 'CARROLL')
      end

      before(:each) do
        allow(JWT).to receive(:decode).and_return(token)
        stub_mvi(mvi_profile)
      end

      it 'should return 200 and add user to session' do
        with_okta_configured do
          Okta::Service.any_instance.stub(:user).and_return(faraday_response)
          allow(faraday_response).to receive(:success?).and_return(true)
          allow(faraday_response).to receive(:body).and_return(okta_response)

          request.headers['Authorization'] = 'Bearer FakeToken'
          get :index
          expect(response).to be_ok
          expect(Session.find('FakeToken')).to_not be_nil
          expect(JSON.parse(response.body)['user']).to eq('vets.gov.user+20@gmail.com')
          expect(JSON.parse(response.body)['icn']).to eq('10000012345V123458')
          expect(JSON.parse(response.body)['last_name']).to eq('CARROLL')
          expect(JSON.parse(response.body)['loa_current']).to eq(3)
        end
      end
    end
  end
end
