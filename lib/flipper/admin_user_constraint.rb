# frozen_string_literal: true

module Flipper
  class AdminUserConstraint
    def current_user_rack(request)
      if (session_token = request.session[:token]) && (session = Session.find(session_token))
        user = User.find(session.uuid)
        # We've set this in a thread because we want to log who has made a change in
        # Flipper::Instrumentation::EventSubscriber but at that point we don't have access to the request or session
        # objects at that point and the request goint to a simple rack app.
        Thread.current[:flipper_user_email_for_log] = user&.email
        user
      else
        Thread.current[:flipper_user_email_for_log] = nil
        nil
      end
    end

    def matches?(request)
      current_user = current_user_rack(request)
      (current_user && Settings.flipper.admin_user_emails.include?(current_user.email) && current_user.loa3?) ||
        request.method == 'GET' || Rails.env.development?
    end
  end
end
