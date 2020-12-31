# frozen_string_literal: true

class Sidekiq::Web::Authorization
  attr_reader :rails_env

  def initialize(rails_env)
    @rails_env = rails_env
  end

  def request_authorized?(rack_env, _method, _path)
    # return true if rails_env.development?

    request = Rack::Request.new(rack_env)
    current_user = current_user_rack(request)

    (
      current_user && # rubocop:disable Style/SafeNavigation
      current_user.loa3? &&
      Settings.sidekiq_web.admin_user_emails.include?(current_user.email)
    )
  end

  private

  def current_user_rack(request)
    if (session_token = request.session[:token]) && (session = Session.find(session_token))
      User.find(session.uuid)
    end
  end
end
