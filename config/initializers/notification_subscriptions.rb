ActiveSupport::Notifications.subscribe 'sessions.new' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  type  = event.payload[:params]['signup'] ? 'signup' : event.payload[:params]['type']
  ip_address = event.payload[:request]&.remote_ip
  user_agent = event.payload[:request]&.user_agent
  SessionActivity.create(name: type, originating_ip_address: ip_address, user_agent: user_agent, created_at: event.end)
  Rails.logger.info("SSO: new #{type.upcase} flow initiated", url: event.payload[:url])
end
