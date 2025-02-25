# frozen_string_literal: true

require 'rails_helper'

# Note these specs MUST be run in order
RSpec.describe 'authenticating loa3 user', order: :defined, type: :request do
  OUTBOUND_CASSETTE = 'complex_interaction/external_interactions'
  # rubocop:disable Lint/StructNewOverride
  Episode = Struct.new(:method, :uri, :body, :headers, :recorded_at, :response)
  # rubocop:enable Lint/StructNewOverride

  EPISODES = begin
    inbound_cassette_path = 'spec/support/vcr_cassettes/complex_interaction/internal_interactions.yml'
    YAML.safe_load(File.read(inbound_cassette_path))['http_interactions'].map do |interaction|
      req = interaction['request']
      req['uri'] = URI.parse(req['uri'])
      req['recorded_at'] = Time.zone.parse(interaction['recorded_at'].to_s).to_datetime
      req['headers'] = req['headers'].transform_values(&:first)
      Episode.new(*req.values, interaction['response'])
    end
  end

  it 'does the tests', :aggregate_failures, :skip_mvi, skip: 'Unknown reason for skip' do
    EPISODES.each_with_index do |episode, _index|
      Timecop.freeze(episode.recorded_at) do
        VCR.use_cassette(OUTBOUND_CASSETTE) do
          SecureRandom.with_disabled_randomness do
            make_request(episode)
          end
        end
      end
      expect(response.status).to eq(episode.response['status']['code'])
      expect(response.body).to match_episode_body(episode.response['body']['string'])
      expect(response.headers.keys).to match_episode_body(episode.response['headers'].keys)
    end
  end

  private

  def make_request(episode)
    params = if episode.method == 'post'
               Rack::Utils.parse_nested_query(episode.body['string'])
             else
               Rack::Utils.parse_nested_query(episode.uri.query)
             end
    send(episode.method, episode.uri.path, params, episode.headers)
  end
end
