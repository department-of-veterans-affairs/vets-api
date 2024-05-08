# config/initializers/00_is_localhost.rb

# The purpose of this top-level method is to be able to change
# the behavior of business logic when the application is specifically
# running on a developers local environment.  For example to return
# to return a successful request code when a missing API returns a
# 404.

def running_on_localhost_in_development?
  if defined?(request)
    Rails.env.development? && request.local?
  else
    # SMELL: This does not account for a possible IPv6 IP Address of ::1
    ['127.0.0.1', 'localhost'].include?(Settings.hostname.split(':').first.downcase) &&
      Settings.virtual_hosts.map(&:downcase).include?('localhost') &&
      Rails.env.development?
  end
end
