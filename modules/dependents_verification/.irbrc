# Disable autocomplete in deployed environments
# to help prevent running unintended commands
if ENV['RAILS_ENV'] == 'production'
  IRB.conf[:USE_AUTOCOMPLETE] = false
end
