# frozen_string_literal: true

Warden::GitHub::User.module_eval do
  def api
    Octokit::Client.new(access_token: Settings.sidekiq.github_api_key)
  end
end

Warden::GitHub::Strategy.module_eval do
  def authenticate!
    if session[:user].present?
      success!(session[:user])
      return session[:user]
    end
    if in_flow?
      continue_flow!
    else
      begin_flow!
    end
  end
end
