# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::TriageTeamsController, type: :controller do
  let(:id) { '10616687' }

  describe 'index' do
    before(:each) do
      VCR.use_cassette('triage_teams/10616687/index') do
        get :index, id: id
      end
    end

    it 'sets the correlation id' do
      expect(assigns(:mhv_correlation_id)).to eq(id)
    end

    it 'establishes a client session' do
      expect(assigns(:client)).to be_kind_of(VAHealthcareMessaging::Client)
    end

    it 'retrieves the triage teams' do
      expect(assigns(:teams)).to be_kind_of(VAHealthcareMessaging::Collection)
    end
  end
end
