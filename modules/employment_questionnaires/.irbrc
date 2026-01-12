# frozen_string_literal: true

# Disable autocomplete in deployed environments
# to help prevent running unintended commands
IRB.conf[:USE_AUTOCOMPLETE] = false if ENV['vsp_environment'] == 'production'
