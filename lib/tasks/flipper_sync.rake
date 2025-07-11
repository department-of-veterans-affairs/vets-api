# frozen_string_literal: true

namespace :flipper do
  desc 'Sync feature toggles from config/features.yml to database'
  task sync: :environment do
    puts "Syncing #{FLIPPER_FEATURE_CONFIG['features'].count} feature toggles..."
    
    added_flippers = []
    start_time = Time.current
    
    begin
      FLIPPER_FEATURE_CONFIG['features'].each do |feature, feature_config|
        unless Flipper.exist?(feature)
          Flipper.add(feature)
          added_flippers.push(feature)

          # Default features to enabled for test and those explicitly set for development
          if Rails.env.test? || (Rails.env.development? && feature_config['enable_in_development'])
            Flipper.enable(feature)
          end
        end

        # Enable features on dev-api.va.gov if they are set to enable_in_development
        if Settings.vsp_environment == 'development' && feature_config['enable_in_development']
          Flipper.enable(feature)
        end
      end

      puts "Added #{added_flippers.count} new feature toggles: #{added_flippers.join(', ')}" unless added_flippers.empty?
      
      # Check for removed features
      removed_features = Flipper.features.collect(&:name) - FLIPPER_FEATURE_CONFIG['features'].keys
      unless removed_features.empty?
        puts "⚠️  Consider removing features no longer in config/features.yml:"
        removed_features.each { |feature| puts "  - #{feature}" }
      end
      
      elapsed = Time.current - start_time
      puts "✅ Flipper sync completed in #{elapsed.round(2)}s"
      
    rescue => e
      puts "❌ Error syncing Flipper features: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end
  
  desc 'Remove obsolete feature toggles not in config/features.yml'
  task cleanup: :environment do
    config_features = FLIPPER_FEATURE_CONFIG['features'].keys
    db_features = Flipper.features.collect(&:name)
    obsolete_features = db_features - config_features
    
    if obsolete_features.empty?
      puts "✅ No obsolete features to remove"
    else
      puts "Removing #{obsolete_features.count} obsolete features:"
      obsolete_features.each do |feature|
        puts "  - #{feature}"
        Flipper.remove(feature)
      end
      puts "✅ Cleanup completed"
    end
  end
end