# frozen_string_literal: true
require 'staccato/adapter/logger'
require 'staccato/adapter/faraday'

trackers = YAML.load_file(Rails.root.join('config', 'google_analytics.yml'))

UA_TRACKERS = trackers.each_with_object({}) do |(name, id), memo|
  memo[name] = Staccato.tracker(id, nil, ssl: true) do |c|
    if Rails.env.production?
      c.adapter = Staccato::Adapter::Faraday.new(Staccato.ga_collection_uri)
    elsif Rails.env.development?
      c.adapter = Staccato::Adapter::Logger.new(Staccato.ga_collection_uri, Logger.new(STDOUT),
                                                ->(params) { JSON.dump(params) })
    else
      c.adapter = Staccato::Adapter::Logger.new(Staccato.ga_collection_uri, Logger.new(StringIO.new))
    end
  end
  memo
end
