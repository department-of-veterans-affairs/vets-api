# frozen_string_literal: true

Spring.watch(
  '.ruby-version',
  '.rbenv-vars',
  'tmp/restart.txt',
  'tmp/caching-dev.txt',
  'config/application.yml',
  'config/settings.yml',
  'config/settings.local.yml'
)
