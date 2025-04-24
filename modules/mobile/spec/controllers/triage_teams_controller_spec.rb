# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::TriageTeamsController, type: :controller do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :mhv) }
  let(:use_all_triage_teams) { false }
  let(:client) { double('client') }

  before do
    sign_in_as(user, build(:access_token))
    allow(controller).to receive(:client).and_return(client)
    allow(Flipper).to receive(:enabled?).with(:mobile_get_expanded_triage_teams, user).and_return(use_all_triage_teams)
  end

  describe '#index' do
    context 'when feature flag is disabled' do
      let(:use_all_triage_teams) { false }
      let(:triage_teams) { build(:triage_team) }

      it 'uses get_triage_teams method' do
        expect(client).to receive(:get_triage_teams).with(user.uuid, true).and_return(
          Common::Collection.new(TriageTeam, data: [triage_teams], metadata: {})
        )

        get :index
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data'].size).to eq(1)
      end
    end

    context 'when feature flag is enabled' do
      let(:use_all_triage_teams) { true }
      let(:blocked_team) { build(:all_triage_team, blocked_status: true) }
      let(:non_blocked_team) { build(:all_triage_team, blocked_status: false) }

      it 'uses get_all_triage_teams method and filters out blocked teams' do
        expect(client).to receive(:get_all_triage_teams).with(user.uuid, true).and_return(
          Common::Collection.new(AllTriageTeams, data: [blocked_team, non_blocked_team], metadata: {})
        )

        get :index
        expect(response).to have_http_status(:ok)

        # Verify we only get non-blocked teams back
        data = JSON.parse(response.body)['data']
        expect(data.size).to eq(1)
        expect(data[0]['attributes']['triage_team_id']).to eq(non_blocked_team.triage_team_id)
      end

      it 'returns empty array when all teams are blocked' do
        expect(client).to receive(:get_all_triage_teams).with(user.uuid, true).and_return(
          Common::Collection.new(AllTriageTeams, data: [blocked_team], metadata: {})
        )

        get :index
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']).to be_empty
      end
    end

    context 'when client returns blank' do
      let(:use_all_triage_teams) { false }

      it 'raises ResourceNotFound' do
        allow(client).to receive(:get_triage_teams).with(user.uuid, true).and_return(nil)

        expect { get :index }.to raise_error(Common::Exceptions::ResourceNotFound)
      end
    end

    context 'when client returns blank with feature flag enabled' do
      let(:use_all_triage_teams) { true }

      it 'raises ResourceNotFound' do
        allow(client).to receive(:get_all_triage_teams).with(user.uuid, true).and_return(nil)

        expect { get :index }.to raise_error(Common::Exceptions::ResourceNotFound)
      end
    end
  end
end
