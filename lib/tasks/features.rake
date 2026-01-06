# frozen_string_literal: true

require 'flipper'

namespace :features do
  desc 'List current Flipper features and their states'
  task list: :environment do
    puts 'Current Flipper Features:'
    Flipper.features.each do |feature|
      state = if Flipper.enabled?(feature.name)
                'ENABLED'
              else
                'disabled'
              end
      puts "- #{feature.name}: #{state}"
    end
  end

  desc 'Setup Flipper features from config/features.yml (adds missing features, removes orphaned features)'
  task setup: :environment do
    FlipperUtils.setup_features
  end
end
