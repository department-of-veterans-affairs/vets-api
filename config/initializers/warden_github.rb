# frozen_string_literal: true

module WardenGitHubUserExtensions
  def api
    Octokit::Client.new(access_token: Settings.sidekiq.github_api_key)
  end
end

module WardenGithubStrategyExtensions
  def authenticate!
    if scope == :sidekiq && session[:sidekiq_user].present?
      success!(session[:sidekiq_user])
      redirect!(request.url)
    else
      super
    end
  end

  def finalize_flow!
    session[:sidekiq_user] = load_user if scope == :sidekiq
    super
  end
end

Warden::GitHub::Strategy.module_eval do
  prepend WardenGithubStrategyExtensions
end

Warden::GitHub::User.module_eval do
  prepend WardenGitHubUserExtensions
end
