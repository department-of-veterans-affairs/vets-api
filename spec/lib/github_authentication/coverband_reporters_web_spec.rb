# frozen_string_literal: true

require 'rails_helper'
require 'coverband'
require 'github_authentication/coverband_reporters_web'

describe GithubAuthentication::CoverbandReportersWeb do
  include Rack::Test::Methods
  include Warden::Test::Helpers

  let(:app) { Coverband::Reporters::Web.new }
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
    allow_any_instance_of(ActionDispatch::Request).to receive(:session) { { coverband_user: user } }
  end

  context 'the user is not an organization member with coverband permissions' do
    it 'halts and returns a 403' do
      allow(user).to receive(:organization_member?).with(Settings.coverband.github_organization).and_return(false)
      response = get '/coverband'
      expect(response.status).to eq 404
    end
  end

  context 'the user is an organization member but not a team member with coverband permissions' do
    it 'halts and returns a 403' do
      allow(user).to receive(:organization_member?).with(Settings.coverband.github_organization).and_return(true)
      allow(user).to receive(:team_member?).with(Settings.coverband.github_team).and_return(false)
      response = get '/coverband'
      expect(response.status).to eq 404
    end
  end
end
