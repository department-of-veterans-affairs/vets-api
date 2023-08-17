# frozen_string_literal: true

module WardenGithubStrategyExtensions
  def authenticate!
    if scope == :sidekiq && session[:sidekiq_user].present?
      success!(session[:sidekiq_user])
      redirect!(request.url)
    elsif scope == :coverband && session[:coverband_user].present?
      success!(session[:coverband_user])
      redirect!(request.url)
    elsif scope == :flipper && session[:flipper_user].present?
      success!(session[:flipper_user])
      redirect!(request.url)
    else
      super
    end
  end

  def finalize_flow!
    session[:sidekiq_user] = load_user if scope == :sidekiq
    session[:coverband_user] = load_user if scope == :coverband
    session[:flipper_user] = load_user if scope == :flipper
    super
  end
end

Warden::GitHub::Strategy.module_eval do
  prepend WardenGithubStrategyExtensions
end
