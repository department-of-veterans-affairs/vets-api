# frozen_string_literal: true

Warden::GitHub::User.module_eval do
  def api
    Octokit::Client.new(access_token: Settings.sidekiq.github_api_key)
  end
end

Warden::GitHub::Strategy.module_eval do
  def authenticate!
    success!(session[:user]) if session[:user].present?
    if in_flow?
      continue_flow!
    else
      begin_flow!
    end
  end
end
