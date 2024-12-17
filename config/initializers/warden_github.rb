# frozen_string_literal: true

module WardenGithubStrategyExtensions
  def authenticate!
    if scope == :sidekiq && session[:sidekiq_user].present?
      success!(session[:sidekiq_user])
      redirect!(request.url)
    elsif scope == :coverband && session[:coverband_user].present?
      success!(session[:coverband_user])
      redirect!(request.url)
    else
      super
    end
  end

  def begin_flow!
    # We want this redirect value for later in the flow
    if request.path.include?('/flipper')
      redirect = request.env['QUERY_STRING']&.split('=')&.[](1)
      custom_session[:redirect] = redirect if redirect.present?
    end

    super
  end

  def finalize_flow!
    session[:sidekiq_user] = load_user if scope == :sidekiq
    session[:coverband_user] = load_user if scope == :coverband
    if scope == :flipper
      # now we can grab the actual URL without the redirect param and redirect to the intended page
      session[:flipper_user] = load_user
      url = custom_session['return_to'].split('?').first
      url += "/#{custom_session[:redirect]}" if custom_session[:redirect]
      custom_session['return_to'] = url
    end

    super
  end
end

Warden::GitHub::Strategy.module_eval do
  prepend WardenGithubStrategyExtensions
end
