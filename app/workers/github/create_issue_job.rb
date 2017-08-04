# frozen_string_literal: true
require 'github/github_service'

module Github
  class CreateIssueJob
    include Sidekiq::Worker

    def perform(feedback)
      Github::GithubService.create_issue(title, feedback.description)
    end
  end
end
