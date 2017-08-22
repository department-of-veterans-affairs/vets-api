# frozen_string_literal: true
require 'rails_helper'

# Note these specs MUST be run in order
RSpec.describe 'authenticating loa3 user', type: :request, order: :defined do
  OUTBOUND_CASSETTE = 'integration/saml_loa3_user/outbound'
  Episode = Struct.new(:method, :uri, :body, :headers, :recorded_at, :response)

  EPISODES = begin
    base = "#{Settings.integration_recorder.base_cassette_dir}/"
    inbound = "#{Settings.integration_recorder.inbound_cassette_dir}.yml"
    file_path = base + inbound
    YAML.load(File.read(file_path))['http_interactions'].map do |interaction|
      req = interaction['request']
      req['uri'] = URI.parse(req['uri'])
      req['recorded_at'] = Time.zone.parse(interaction['recorded_at'].to_s).to_datetime
      req['headers'] = Hash[req['headers'].map { |k, v| [k, v.first] }]
      Episode.new(*req.values, interaction['response'])
    end
  end

  VCR.use_cassette(OUTBOUND_CASSETTE, record: :none, match_requests_on: %i(headers)) do
    it 'does the tests', :aggregate_failures do
      EPISODES.each_with_index do |episode, _index|
        # it "#{(index + 1).ordinalize} responds to #{episode.method} #{episode.uri.path}" do
        # Stubbing the session token to return whats provided in the recorded Authorization Headers
        allow_any_instance_of(Session)
          .to receive(:secure_random_token).and_return('1BNxPrdS1uRxF23dsKsxxyhD73Vg3exZpjox-ekf')
        Timecop.freeze(episode.recorded_at)
        if episode.uri.path == '/v0/sessions/new'
          e_resp = JSON.parse(episode.response['body']['string'])['authenticate_via_get']
          expect_any_instance_of(OneLogin::RubySaml::Authrequest)
            .to receive(:create).once.and_return(e_resp)
        end

        make_request(episode)
        expect(response.status).to eq(episode.response['status']['code'])
        expect(response.body).to eq(episode.response['body']['string'])
        # end
      end
    end
  end

  it 'has 11 steps' do
    expect(EPISODES.size).to eq(11)
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
