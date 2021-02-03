# frozen_string_literal: true

module CypressViewportUpdater
  class GithubService
    include SentryLogging

    PRIVATE_KEY = OpenSSL::PKey::RSA.new(Settings.github_cvu.private_pem].gsub('\n', "\n"))
    INSTALLATION_ID = Settings.github_cvu.installation_id
    INTEGRATION_ID = Settings.github_cvu.integration_id
    REPO = 'department-of-veterans-affairs/vets-website'

    attr_reader :client, :feature_branch_name

    def initialize
      @client = Octokit::Client.new(bearer_token: new_jwt_token)
      response = @client.create_installation_access_token(INSTALLATION_ID,
                                                          accept: 'application/vnd.github.v3+json')
      @client.bearer_token = response.to_h[:token]
    end

    def get_content(file:)
      begin
        file.sha = @client.content(REPO, path: file.github_path).sha
        file.raw_content = @client.content(REPO, path: file.github_path, accept: 'application/vnd.github.V3.raw')
      rescue Octokit::ClientError, Octokit::UnprocessableEntity, StandardError => e
        log_exception_to_sentry(e)
      end

      self
    end

    def create_branch
      set_feature_branch_name
      ref = "heads/#{feature_branch_name}"

      begin
        sha = @client.ref(REPO, 'heads/master').object.sha
        @client.create_ref(REPO, ref, sha)
      rescue Octokit::ClientError, Octokit::UnprocessableEntity, StandardError => e
        log_exception_to_sentry(e)
      end
    end

    def update_content(file:)
      @client.update_content(REPO,
                             file.github_path,
                             "update #{file.name}",
                             file.sha,
                             file.updated_content,
                             branch: feature_branch_name)
    rescue Octokit::ClientError, Octokit::UnprocessableEntity, StandardError => e
      log_exception_to_sentry(e)
    end

    def submit_pr
      @client.create_pull_request(REPO,
                                  'master',
                                  feature_branch_name,
                                  pr_title,
                                  pr_body)
    rescue Octokit::ClientError, Octokit::UnprocessableEntity, StandardError => e
      log_exception_to_sentry(e)
    end

    private

    attr_writer :feature_branch_name

    def new_jwt_token
      payload = {
        # issued at time
        iat: Time.now.to_i,
        # JWT expiration time (10 minute maximum)
        exp: Time.now.to_i + (10 * 60),
        # GitHub App's identifier
        iss: INTEGRATION_ID
      }

      JWT.encode(payload, PRIVATE_KEY, 'RS256')
    end

    def set_feature_branch_name
      prefix = DateTime.now.strftime('%m%d%Y%H%M%S%L')
      name = 'update_cypress_viewport_data'
      self.feature_branch_name = prefix + '_' + name
    end

    def pr_title
      'Update Cypress Viewport Data (Automatic Update)'
    end

    def pr_body
      last_month = Time.zone.today.prev_month.strftime('%m/%Y')

      'Updates `config/cypress.json` and ' \
      '`src/platform/testing/e2e/cypress/support/commands/viewportPreset.js` ' \
      "with Google Analytics viewport data from last month (#{last_month}).\n\n" \
      'These files are updated automatically via a Sidekiq job in `vets-api` ' \
      'that runs at noon on the 2nd day of each month to get the analytics data ' \
      'for the previous month. (Google Analytics updates every 24 hours.)'
    end
  end
end
