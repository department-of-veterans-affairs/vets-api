# frozen_string_literal: true

require 'rails_helper'

describe GithubAuthentication::SidekiqWeb do
  include Rack::Test::Methods
  include Warden::Test::Helpers

  let(:app) { Sidekiq::Web.new }
  let(:default_attrs) do
    { 'login' => 'john',
      'name' => 'John Doe',
      'gravatar_id' => '38581cb351a52002548f40f8066cfecg',
      'avatar_url' => 'http://example.com/avatar.jpg',
      'email' => 'john@doe.com',
      'company' => 'Doe, Inc.' }
  end
  let(:user) { Warden::GitHub::User.new(default_attrs) }

  before do
    allow_any_instance_of(Warden::Proxy).to receive(:authenticate!).and_return(user)
    allow_any_instance_of(Warden::Proxy).to receive(:user).and_return(user)
    Sidekiq::Web.use Rack::Session::Cookie, secret: 'a' * 64, same_site: true
    Sidekiq::Web.use Warden::Manager do |config|
      config.failure_app = Sidekiq::Web
    end
  end

  context 'the user is not an organization member' do
    it 'halts and returns a 403' do
      allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(false)
      response = get '/'
      expect(response.status).to eq 403
    end
  end

  context 'the user is an organization member but not a team member' do
    it 'halts and returns a 403' do
      allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(true)
      allow(user).to receive(:team_member?).with(Settings.sidekiq.github_team).and_return(false)

      response = get '/'
      expect(response.status).to eq 403
    end
  end

  context 'the user is an organization member and a team member' do
    it 'returns a 200' do
      allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(true)
      allow(user).to receive(:team_member?).with(Settings.sidekiq.github_team).and_return(true)
      response = get '/'

      expect(response.status).to eq 200
    end
  end
end
