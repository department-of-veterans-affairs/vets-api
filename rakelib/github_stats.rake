# frozen_string_literal: true

require 'httparty'
require 'date'

STATSD_ERROR_KEY = 'worker.github_stats_scraper.error'

REPOS = %w[
  vets-api
  vets-website
].freeze

PR_KEYS = %w[
  created_at
  updated_at
  head
].freeze

namespace :github_stats do
  desc 'Hit the Github API and grab data on open PRs'
  task get_open_prs: :environment do
    # hit API endpoints for vets-api and vets-website to get open PRs and add data to array
    responses = []
    REPOS.each do |repo|
      url = "https://api.github.com/repos/department-of-veterans-affairs/#{repo}/pulls?state=open&per_page=100"
      resp = HTTParty.get(url)
      responses.concat(resp)
    end
    # iterate thru responses and collect just the needed data
    open_prs = []
    responses.each do |response|
      h = {}
      response.each do |k, v|
        next unless PR_KEYS.include?(k)

        if k == 'head'
          h['repo_name'] = (v['repo']['name']).to_s
        else
          h[k.to_s] = v.to_s
        end
      end
      h['duration'] = (DateTime.now - DateTime.parse(h['updated_at']))
      open_prs << h
    end
    # send each duration to StatsD
    open_prs.each do |pr|
      StatsD.measure('github:pull_request_duration', pr['duration'], tags: { repo: pr['repo_name'] })
    end
  end
end
