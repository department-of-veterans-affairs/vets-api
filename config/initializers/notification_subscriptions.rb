ActiveSupport::Notifications.subscribe 'sessions.new' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  type  = event.payload[:params]['signup'] ? 'signup' : event.payload[:params]['type']
  SessionActivity.create(name: type, created_at: event.end)
  Rails.logger.info("SSO: new #{type.upcase} flow initiated", url: event.payload[:url])
end
