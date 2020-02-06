# frozen_string_literal: true

require 'httparty'
require 'date'

class GithubStatsJob
  include Sidekiq::Worker

  sidekiq_options queue: 'low', retry: false

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

  def get_open_prs
    responses = get_repo_data
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
      h['duration'] = (DateTime.now - h['updated_at'].parse)
      open_prs << h
    end
    open_prs
  end

  def get_repo_data
    responses = []
    REPOS.each do |repo|
      url = "https://api.github.com/repos/department-of-veterans-affairs/#{repo}/pulls?state=open&per_page=100"
      resp = HTTParty.get(url)
      responses.concat(resp)
    end
    responses
  end

  def perform
    open_prs = get_open_prs
    open_prs.each do |pr|
      StatsD.measure('github:pull_request_duration', pr['duration'], tags: [repo: pr['repo_name']])
    end
  rescue => e
    Rails.logger.error(
      "Error performing GithubStatsJob: #{e.message}",
      original_event: event
    )
    StatsD.increment(STATSD_ERROR_KEY)
  end
end
