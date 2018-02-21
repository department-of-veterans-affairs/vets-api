# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  describe 'triage_teams' do
    before(:all) do
      VCR.use_cassette 'sm_client/session', record: :new_episodes do
        @client ||= begin
          client = SM::Client.new(session: { user_id: '10616687' })
          client.authenticate
          client
        end
      end
    end

    subject(:client) { @client }

    it 'gets a collection of triage team recipients', :vcr do
      folders = client.get_triage_teams
      expect(folders).to be_a(Common::Collection)
      expect(folders.type).to eq(TriageTeam)
    end
  end
end
