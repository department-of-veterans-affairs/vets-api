# frozen_string_literal: true

require 'octokit'
require 'sentry_logging'

module Representatives
  # Class responsible for fetching the XLSX file containing representative organization addresses
  # from a specified GitHub repository.
  class XlsxFileFetcher
    include SentryLogging

    # Constants defining the GitHub organization, repository, and file path.
    ORG = 'department-of-veterans-affairs'
    REPO = 'va.gov-team-sensitive'
    PATH = 'products/accredited-representation-management/data/rep-org-addresses.xlsx'

    # Fetches the XLSX file content from the GitHub repository.
    # @return [String, nil] The content of the file as a string, or nil if not fetched.
    def fetch
      setup_octokit_client
      return nil unless file_recently_updated?

      file_info = fetch_rep_addresses_file_info
      fetch_file_content(file_info.download_url)
    rescue => e
      log_error("Error fetching XLSX file: #{e.message}")
      nil
    end

    private

    # Sets up the Octokit GitHub client with an access token.
    def setup_octokit_client
      @client = Octokit::Client.new(access_token: fetch_github_access_token)
    end

    # Fetches the GitHub access token from application configuration.
    # @return [String] The GitHub access token.
    def fetch_github_access_token
      Settings.veteran.xlsx_file_fetcher.github_access_token
    end

    # Retrieves the file information for the XLSX file from GitHub.
    # @return [Sawyer::Resource] The file information resource from GitHub.
    def fetch_rep_addresses_file_info
      @client.contents("#{ORG}/#{REPO}", path: PATH)
    end

    # Checks if the file has been updated in the last 24 hours.
    # @return [Boolean] True if the file was recently updated, false otherwise.
    def file_recently_updated?
      commits = @client.commits("#{ORG}/#{REPO}", path: PATH)
      return false if commits.empty?

      last_commit_date = commits.first.commit.author.date
      last_commit_date > 24.hours.ago
    rescue Octokit::Error => e
      log_error("Error fetching XLSX file GitHub commits: #{e.message}")
      false
    end

    # Downloads the file content from a given URL.
    # @param url [String] The URL to download the file content from.
    # @return [String] The body of the HTTP response, or nil if not successful.
    def fetch_file_content(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      response.body if response.is_a?(Net::HTTPSuccess)
    end

    # Logs an error to Sentry.
    # @param message [String] The error message to be logged.
    def log_error(message)
      log_message_to_sentry("XlsxFileFetcher error: #{message}", :error)
    end
  end
end
