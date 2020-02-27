# frozen_string_literal: true

STATSD_METRIC = 'tasks.github_stats_scraper.duration'

REPOS = %w[
  vets-api
  vets-website
].freeze

namespace :github_stats do
  desc 'Hit the Github API and grab data on open PRs'
  task get_open_prs: :environment do
    # hit API endpoints for vets-api and vets-website to get open PRs and add data to hash
    responses = {}
    REPOS.each do |repo|
      url = "https://api.github.com/repos/department-of-veterans-affairs/#{repo}/pulls?state=open&per_page=100"
      uri = URI(url)
      resp = Net::HTTP.get(uri)
      responses[repo] = resp
    end
    # iterate thru responses and collect just the needed data
    responses.each do |repo, json_response|
      open_prs = JSON.parse(json_response)
      open_prs.each do |pr|
        # parse vals from json
        user = pr['user']['login']
        number = pr['number']
        pr_created_at = DateTime.parse(pr['created_at']).to_f
        pr_url = pr['url']
        reviews_url = "#{pr_url}/reviews"
        # determine first_reviewed date
        uri = URI(reviews_url)
        resp = Net::HTTP.get(uri)
        first = JSON.parse(resp).first
        first_reviewed = if first.nil?
                           # PR has not yet been reviewed so use current timestamp
                           DateTime.now.to_f
                         else
                           DateTime.parse(first['submitted_at']).to_f
                         end
        # calculate the duration
        duration = (first_reviewed - pr_created_at).round

        # send duration to StatsD
        StatsD.measure(STATSD_METRIC, duration,
                       tags: { repo: repo, number: number, user: user })
      end
    end
  end
end
