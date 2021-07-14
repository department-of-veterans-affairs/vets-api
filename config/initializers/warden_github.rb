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
      redirect!(request.url)
    elsif in_flow?
      continue_flow!
    else
      begin_flow!
    end
  end

  def finalize_flow!
    session[:user] = load_user
    redirect!(custom_session['return_to'])
    teardown_flow
    throw(:warden)
  end
end
