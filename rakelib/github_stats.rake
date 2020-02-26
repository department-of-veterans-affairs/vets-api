# frozen_string_literal: true

STATSD_METRIC = 'tasks.github_stats_scraper.duration'

REPOS = %w[
  vets-api
  vets-website
].freeze

namespace :github_stats do
  desc 'Hit the Github API and grab data on open PRs'
  task get_open_prs: :environment do
    # determine if/when a PR was first responded to
    def get_first_responded_at(url)
      uri = URI(url)
      resp = Net::HTTP.get(uri)
      first = JSON.parse(resp).first
      # determine type of response
      first_responded_at = if first.nil?
                             # PR has not yet been reviewed so use current timestamp
                             DateTime.now.to_f
                           elsif first['submitted_at'].nil?
                             # PR is either a comment or review_comment
                             DateTime.parse(first['created_at']).to_f
                           else
                             # PR is a review
                             DateTime.parse(first['submitted_at']).to_f
                           end
      first_responded_at
    end

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
        pr_url = pr['url']
        user = pr['user']['login']
        number = pr['number']
        pr_created_at = DateTime.parse(pr['created_at']).to_f
        comments = pr['comments'].to_i
        comments_url = pr['comments_url']
        review_comments = pr['review_comments'].to_i
        review_comments_url = pr['review_comments_url']
        reviews_url = "#{pr_url}/reviews"
        # determine first_responded_at date
        first_responded_at = if comments.positive?
                               get_first_responded_at(comments_url)
                             elsif review_comments.positive?
                               get_first_responded_at(review_comments_url)
                             else
                               get_first_responded_at(reviews_url)
                             end
        # calculate the duration
        duration = (first_responded_at - pr_created_at).round

        # send duration to StatsD
        StatsD.measure(STATSD_METRIC, duration,
                       tags: { repo: repo, number: number, user: user })
      end
    end
  end
end
