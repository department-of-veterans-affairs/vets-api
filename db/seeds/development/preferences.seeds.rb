# frozen_string_literal: true

Rake::Task['preferences:initial_seed'].invoke
Rails.logger.info 'Preferences have been seeded'
