# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client, '#message_sending_helpers' do
  let(:client) { described_class.new(session: { user_id: '10616687' }) }

  before do
    allow(client).to receive(:token_headers).and_return({})
  end

  describe '#track_message_station_metric' do
    let(:recipient_id) { 613_586 }
    let(:message) { build(:message, recipient_id:) }

    context 'when cached triage teams contain a match' do
      let(:station_number) { '989' }

      before do
        cached_teams = [
          TriageTeamCache.new(triage_team_id: recipient_id, station_number:),
          TriageTeamCache.new(triage_team_id: 999_999, station_number: '123')
        ]
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(cached_teams)
      end

      it 'sends a StatsD metric with the matching station_number tag' do
        expect(StatsD).to receive(:increment).with(
          'mhv.sm.api.client.message_sent_to_station',
          tags: array_including("station_number:#{station_number}")
        )
        client.send(:track_message_station_metric, message)
      end
    end

    context 'when cached triage teams have no match for recipient_id' do
      before do
        cached_teams = [
          TriageTeamCache.new(triage_team_id: 999_999, station_number: '123')
        ]
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(cached_teams)
      end

      it 'sends a StatsD metric with station_number:unknown' do
        expect(StatsD).to receive(:increment).with(
          'mhv.sm.api.client.message_sent_to_station',
          tags: array_including('station_number:unknown')
        )
        client.send(:track_message_station_metric, message)
      end
    end

    context 'when cached triage teams are empty' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_return([])
      end

      it 'sends a StatsD metric with station_number:unknown' do
        expect(StatsD).to receive(:increment).with(
          'mhv.sm.api.client.message_sent_to_station',
          tags: array_including('station_number:unknown')
        )
        client.send(:track_message_station_metric, message)
      end
    end

    context 'when cached triage teams are nil' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(nil)
      end

      it 'sends a StatsD metric with station_number:unknown' do
        expect(StatsD).to receive(:increment).with(
          'mhv.sm.api.client.message_sent_to_station',
          tags: array_including('station_number:unknown')
        )
        client.send(:track_message_station_metric, message)
      end
    end

    context 'when message has no recipient_id' do
      let(:message) { build(:message, recipient_id: nil) }

      it 'does not send a StatsD metric' do
        expect(StatsD).not_to receive(:increment)
        client.send(:track_message_station_metric, message)
      end
    end

    context 'when message is nil' do
      it 'does not send a StatsD metric' do
        expect(StatsD).not_to receive(:increment)
        client.send(:track_message_station_metric, nil)
      end
    end

    context 'when an error occurs during lookup' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_raise(StandardError, 'cache failure')
      end

      it 'logs the error and does not raise' do
        expect(Rails.logger).to receive(:error).with('Error tracking message station metric: cache failure')
        expect { client.send(:track_message_station_metric, message) }.not_to raise_error
      end
    end
  end

  describe '#resolve_station_number' do
    let(:recipient_id) { 613_586 }

    context 'when a matching team is cached' do
      before do
        cached_teams = [
          TriageTeamCache.new(triage_team_id: recipient_id, station_number: '989'),
          TriageTeamCache.new(triage_team_id: 999_999, station_number: '456')
        ]
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(cached_teams)
      end

      it 'returns the station_number' do
        expect(client.send(:resolve_station_number, recipient_id)).to eq('989')
      end
    end

    context 'when no matching team is cached' do
      before do
        cached_teams = [
          TriageTeamCache.new(triage_team_id: 999_999, station_number: '456')
        ]
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(cached_teams)
      end

      it 'returns nil' do
        expect(client.send(:resolve_station_number, recipient_id)).to be_nil
      end
    end

    context 'when cache is empty' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_return([])
      end

      it 'returns nil' do
        expect(client.send(:resolve_station_number, recipient_id)).to be_nil
      end
    end

    context 'when cache is nil' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(nil)
      end

      it 'returns nil' do
        expect(client.send(:resolve_station_number, recipient_id)).to be_nil
      end
    end
  end
end
