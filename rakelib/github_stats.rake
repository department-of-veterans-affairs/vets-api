# frozen_string_literal: true

STATSD_METRIC = 'tasks.github_stats_scraper.duration'

REPOS = %w[
  vets-api
  vets-website
].freeze

namespace :github_stats do
  desc 'Hit the Github API and grab data on open PRs'
  task get_open_prs: :environment do
    # call the Github API and pass along the response body
    def get_response_body(url)
      # get username and token for authenticated calls to Github API
      username = Settings.github_stats.username
      token = Settings.github_stats.token
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(username, token)
      resp = http.request(request)
      resp.body
    end

    # setup calculator for determining duration that excludes weekends
    schedule = { %i[mon tue wed thu fri] => [[0 * 3600, 24 * 3600]] }
    calculator = OperatingHours::Calculator.new(schedule:)
    # get open PRs for vets-api and vets-website and add data to hash
    responses = {}
    REPOS.each do |repo|
      url = "https://api.github.com/repos/department-of-veterans-affairs/#{repo}/pulls?state=open&per_page=100"
      resp = get_response_body(url)
      responses[repo] = resp
    end
    # iterate thru responses and collect just the needed data
    responses.each do |repo, json_response|
      open_prs = JSON.parse(json_response)
      open_prs.map do |pr|
        # parse vals from json
        user = pr['user']['login']
        number = pr['number']
        pr_created_at = DateTime.parse(pr['created_at'])
        pr_url = pr['url']
        reviews_url = "#{pr_url}/reviews"
        # determine first_reviewed date
        resp = get_response_body(reviews_url)
        first = JSON.parse(resp).first

        next if first.nil? # PR has not been reviewed yet, do not measure

        first_reviewed_at = DateTime.parse(first['submitted_at'])
        # calculate the duration excluding weekends
        duration = calculator.seconds_between_times(pr_created_at, first_reviewed_at)

        # send duration to StatsD
        StatsD.measure(STATSD_METRIC, duration,
                       tags: { repo:, number:, user: })
      end.compact
    end
  end
end
