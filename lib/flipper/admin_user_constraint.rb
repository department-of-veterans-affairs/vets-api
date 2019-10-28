# frozen_string_literal: true

module Flipper
  class AdminUserConstraint
    def current_user_rack(request)
      if (session_token = request.session[:token]) && (session = Session.find(session_token))
        User.find(session.uuid)
      end
    end

    def matches?(request)
      current_user = current_user_rack(request)
      current_user && Settings.flipper.admin_user_emails.include?(current_user.email) && current_user.loa3?
    end
  end
end
