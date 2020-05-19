# Run sidekiq-admin: `SIDEKIQ_USERNAME=foo SIDEKIQ_PASSWORD=bar b bundle exec rackup sidekiq-admin.ru -p 9292`

require 'sidekiq'
require 'sidekiq-pro'
require 'sidekiq-scheduler/web'
require 'sidekiq/pro/web'

Sidekiq.configure_client do |config|
  config.redis = { :size => 1 }
end

map '/sidekiq' do
  use Rack::Auth::Basic, "Protected Area" do |username, password|
    Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
      Rack::Utils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
  end

  run Sidekiq::Web
end
