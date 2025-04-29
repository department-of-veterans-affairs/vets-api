# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::TriageTeamAdapter do
  describe '.filter_blocked_teams' do
    it 'filters out triage teams with blocked_status=true' do
      # Create test data
      blocked_team = build(:all_triage_team, blocked_status: true)
      non_blocked_team1 = build(:all_triage_team, blocked_status: false)
      non_blocked_team2 = build(:all_triage_team, blocked_status: false)

      teams = [blocked_team, non_blocked_team1, non_blocked_team2]

      # Filter teams
      filtered_teams = described_class.filter_blocked_teams(teams)

      # Expect only non-blocked teams to be included
      expect(filtered_teams).to include(non_blocked_team1)
      expect(filtered_teams).to include(non_blocked_team2)
      expect(filtered_teams).not_to include(blocked_team)
      expect(filtered_teams.length).to eq(2)
    end

    it 'returns empty array when all teams are blocked' do
      # Create test data with all blocked teams
      blocked_team1 = build(:all_triage_team, blocked_status: true)
      blocked_team2 = build(:all_triage_team, blocked_status: true)

      teams = [blocked_team1, blocked_team2]

      # Filter teams
      filtered_teams = described_class.filter_blocked_teams(teams)

      # Expect empty array
      expect(filtered_teams).to be_empty
    end

    it 'returns all teams when none are blocked' do
      # Create test data with no blocked teams
      team1 = build(:all_triage_team, blocked_status: false)
      team2 = build(:all_triage_team, blocked_status: false)

      teams = [team1, team2]

      # Filter teams
      filtered_teams = described_class.filter_blocked_teams(teams)

      # Expect all teams
      expect(filtered_teams).to eq(teams)
    end
  end
end
