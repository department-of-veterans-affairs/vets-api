# frozen_string_literal: true

# Set proper encoding for Spring
%w[LANG LC_ALL].each { |v| ENV[v] = 'en_US.UTF-8' }

# Configure Spring to handle encoding properly
Spring.after_fork do
  # Force UTF-8 encoding
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

Spring.watch(
  '.ruby-version',
  '.rbenv-vars',
  'tmp/restart.txt',
  'tmp/caching-dev.txt',
  'config/application.yml',
  'config/settings.yml',
  'config/settings.local.yml'
)
