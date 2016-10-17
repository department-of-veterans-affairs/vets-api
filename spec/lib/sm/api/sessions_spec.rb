# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

describe SM::Client do
  include SM::ClientHelpers

  subject(:client) { setup_client }

  before(:each) do
    expect(client.session.token).to be_nil
  end

  before(:all) do
    VCR.turn_off!
  end

  after(:all) do
    VCR.turn_on!
  end

  it 'should have #get_session method' do
    session = client.get_session
    expect(session).to be_a(SM::ClientSession)
    expect(client.session.token).to be_nil
  end

  it 'should have #authenticate method which calls get_session but assigns new session' do
    session = client.authenticate
    expect(session).to be_a(SM::ClientSession)
    expect(client.session.token).to eq('GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahi7CjswZe8SZGKMUVFIU88=')
  end
end
