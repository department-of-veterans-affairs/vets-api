# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'SAML SLO', type: :request do
  let(:rubysaml_settings) { FactoryGirl.build(:rubysaml_settings) }
  let(:user) { FactoryGirl.create(:mvi_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:saml_settings).and_return(rubysaml_settings)
  end

  it 'commences the logout' do
    delete '/v0/sessions', {}, 'Authorization' => "Token token=#{session.token}"
    expect(response.status).to eq(302)
    expect(response.headers['Location']).to match(%r{https://api\.idmelabs\.com/saml/SingleLogoutService})
  end

  it 'handles the completed logout' do
    delete '/v0/sessions', {}, 'Authorization' => "Token token=#{session.token}"
  end
end
