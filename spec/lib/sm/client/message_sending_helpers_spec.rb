# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client, '#message_sending_helpers' do
  let(:client) { described_class.new(session: { user_id: '10616687' }) }

  before do
    allow(client).to receive(:token_headers).and_return({})
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

      it 'returns the station_number with integer recipient_id' do
        expect(client.send(:resolve_station_number, recipient_id)).to eq('989')
      end

      it 'returns the station_number with string recipient_id' do
        expect(client.send(:resolve_station_number, recipient_id.to_s)).to eq('989')
      end
    end

    context 'when no matching team is cached' do
      before do
        cached_teams = [
          TriageTeamCache.new(triage_team_id: 999_999, station_number: '456')
        ]
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(cached_teams)
      end

      it 'returns unknown' do
        expect(client.send(:resolve_station_number, recipient_id)).to eq('unknown')
      end
    end

    context 'when cache is empty' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_return([])
      end

      it 'returns unknown' do
        expect(client.send(:resolve_station_number, recipient_id)).to eq('unknown')
      end
    end

    context 'when cache is nil' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_return(nil)
      end

      it 'returns unknown' do
        expect(client.send(:resolve_station_number, recipient_id)).to eq('unknown')
      end
    end

    context 'when recipient_id is nil' do
      it 'returns unknown' do
        expect(client.send(:resolve_station_number, nil)).to eq('unknown')
      end
    end

    context 'when recipient_id is blank' do
      it 'returns unknown' do
        expect(client.send(:resolve_station_number, '')).to eq('unknown')
      end
    end

    context 'when recipient_id is non-numeric' do
      it 'returns unknown' do
        expect(client.send(:resolve_station_number, 'abc')).to eq('unknown')
      end
    end

    context 'when an error occurs during lookup' do
      before do
        allow(client).to receive(:get_triage_teams_station_numbers).and_raise(StandardError, 'cache failure')
      end

      it 'logs the error and returns unknown' do
        expect(Rails.logger).to receive(:error).with('Error resolving station number: cache failure')
        expect(client.send(:resolve_station_number, recipient_id)).to eq('unknown')
      end
    end
  end
end
