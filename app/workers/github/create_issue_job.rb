# frozen_string_literal: true
require 'github/github_service'

module Github
  class CreateIssueJob
    include Sidekiq::Worker

    # :nocov:
    def perform(feedback)
      Github::GithubService.create_issue(feedback)
    end
    # :nocov:
  end
end
