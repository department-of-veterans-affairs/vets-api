# frozen_string_literal: true

class Sidekiq::Web::Authorization
  class << self
    def request_authorized?(rack_env, rack_req_method, _rack_req_path)
      # return true if development_env?
      return false unless rack_req_method == 'GET'

      request       = Rack::Request.new(rack_env)
      current_user  = current_user_rack(request)

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

    def development_env?
      ENV['RAILS_ENV'] == 'development'
    end
  end
end
