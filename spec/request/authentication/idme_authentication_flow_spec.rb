# frozen_string_literal: true
require 'rails_helper'

# Note these specs MUST be run in order
RSpec.describe 'idme flow', type: :request, order: :defined do
  BASE_PATH = 'complex_interactions/idme_flow'
  OUTBOUND_CASSETTE = "#{BASE_PATH}/external_interactions"
  INBOUND_FULL_PATH = "spec/support/vcr_cassettes/#{BASE_PATH}/internal_interactions.yml"
  Episode = Struct.new(:method, :uri, :body, :headers, :recorded_at, :response)
  EPISODES = begin
    YAML.load(File.read(INBOUND_FULL_PATH))['http_interactions'].map do |interaction|
      req = interaction['request']
      req['uri'] = URI.parse(req['uri'])
      req['recorded_at'] = Time.zone.parse(interaction['recorded_at'].to_s).to_datetime
      req['headers'] = Hash[req['headers'].map { |k, v| [k, v.first] }]
      Episode.new(*req.values, interaction['response'])
    end
  end

  it 'does the tests', :aggregate_failures, :skip_mvi, :skip_emis do
    EPISODES.each_with_index do |episode, _index|
      Timecop.freeze(episode.recorded_at) do
        VCR.use_cassette(OUTBOUND_CASSETTE, record: :new_episodes) do
          SecureRandom.with_disabled_randomness do
            puts 'TESTING SECURE RANDOM FROZEN'
            puts SecureRandom.hex(10)
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

  RSpec::Matchers.define :match_episode_body do |expected|
    match do |actual|
      actual == expected
    end

    failure_message do |actual|
      message = "expected that #{actual} would match #{expected}"
      outputs = [actual, expected].map { |a| pretty(a) }
      message += "\nDiff:" + differ.diff_as_string(*outputs)
      message
    end

    def pretty(output)
      JSON.pretty_generate(JSON.parse(output))
    rescue
      output
    end

    def differ
      RSpec::Support::Differ.new(
        object_preparer: ->(object) { RSpec::Matchers::Composable.surface_descriptions_in(object) },
        color: RSpec::Matchers.configuration.color?
      )
    end
  end

  def make_request(episode)
    params = if episode.method == 'post'
               Rack::Utils.parse_nested_query(episode.body['string'])
             else
               Rack::Utils.parse_nested_query(episode.uri.query)
             end
    send(episode.method, episode.uri.path, params, episode.headers)
  end
end
