# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestUserDashboard::OAuthController, type: :request do
  describe '#index' do
    before do
      # use RSpec mocks to avoid pinging live APIs during tests
      allow_any_instance_of(described_class).to receive(:authenticated?).and_return(true)
      allow_any_instance_of(described_class).to receive(:authorized?).and_return(true)
    end

    let(:url) do
      Settings.vsp_environment == 'staging' ? 'https://tud.vfs.va.gov/signin' : 'http://localhost:8000/signin'
    end

    it 'redirects to the signin url' do
      get('/test_user_dashboard/oauth')

      expect(response).to have_http_status(:redirect)
      expect(response.headers['Location']).to eq(url)
    end
  end

  describe '#authenticated_and_authorized?' do
    context 'authorized user' do
      let!(:github_user) do
        {
          id: 1,
          login: 'tedlasso',
          email: 'tedlasso@richmond.uk.co',
          name: 'Ted Lasso',
          avatar_url: 'https://en.wikipedia.org/wiki/Ted_Lasso'
        }
      end

      before do
        allow_any_instance_of(described_class).to receive(:authorized?).and_return(true)
        allow_any_instance_of(Warden::GitHub::User).to receive(:id).and_return(github_user[:id])
        allow_any_instance_of(Warden::GitHub::User).to receive(:login).and_return(github_user[:login])
        allow_any_instance_of(Warden::GitHub::User).to receive(:email).and_return(github_user[:email])
        allow_any_instance_of(Warden::GitHub::User).to receive(:name).and_return(github_user[:name])
        allow_any_instance_of(Warden::GitHub::User).to receive(:avatar_url).and_return(github_user[:avatar_url])
      end

      it 'renders a successful response' do
        get('/test_user_dashboard/oauth/is_authorized')

        expect(response).to have_http_status(:ok)
      end

      it 'returns the current_user' do
        # allow_any_instance_of(described_class).to receive(:warden).and_return(warden)
        allow_any_instance_of(Warden::Proxy).to receive(:user).with(:tud).and_return(github_user)
        allow_any_instance_of(described_class).to receive(:set_current_user).and_return(github_user)
        get('/test_user_dashboard/oauth/is_authorized')
      end
    end
  end

  describe '#logout' do
    before do
      # use RSpec mocks to avoid pinging live APIs during tests
      allow_any_instance_of(described_class).to receive(:authenticated?).and_return(true)
      allow_any_instance_of(described_class).to receive(:github_user_details).and_return(true)
    end

    let(:url) do
      Settings.vsp_environment == 'staging' ? 'https://tud.vfs.va.gov' : 'http://localhost:8000'
    end

    it 'redirects home' do
      get('/test_user_dashboard/oauth/logout')

      expect(response).to have_http_status(:redirect)
      expect(response.headers['Location']).to eq(url)
    end
  end
end
