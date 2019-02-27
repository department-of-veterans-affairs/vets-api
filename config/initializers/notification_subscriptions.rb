ActiveSupport::Notifications.subscribe 'sessions.new' do |*args|
  binding.pry
  Rails.logger.info("SSO: new #{params[:type]&.upcase} flow initiated", sso_logging_info.merge(url: url))
end
