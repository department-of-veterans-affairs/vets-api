ActiveSupport::Notifications.subscribe 'sessions.new' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Rails.logger.info("SSO: new #{event.payload[:type].upcase} flow initiated", url: event.payload[:url])
end
