# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::TriageTeamsController, type: :controller do
  let(:id) { ENV['MHV_SM_USER_ID'] }

  describe 'index' do
    before(:each) do
      VCR.use_cassette("triage_teams/#{id}/index") do
        get :index, id: id
      end
    end

    it 'establishes a client session' do
      expect(assigns(:client)).to be_kind_of(VAHealthcareMessaging::Client)
    end
  end
end
