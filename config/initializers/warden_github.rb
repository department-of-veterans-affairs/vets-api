# frozen_string_literal: true

Warden::GitHub::User.module_eval do
  def api
    Octokit::Client.new(access_token: Settings.github.api_key)
  end
end
