# frozen_string_literal: true

module CypressViewportUpdater
  class ExistingGithubFile
    attr_reader :github_path, :name
    attr_accessor :sha, :raw_content, :updated_content

    def initialize(github_path:, name:)
      @github_path = github_path
      @name = name
    end
  end
end
