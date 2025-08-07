# frozen_string_literal: true

namespace :flipper do
  desc 'Delete unused flipper toggles that are not defined in the features.yml. Use FORCE=true to skip confirmation.'
  task delete_unused_toggles: :environment do
    # Load features from features.yml
    features_file = Rails.root.join('config', 'features.yml')
    features_config = YAML.load_file(features_file)
    defined_features = features_config['features'].keys.map(&:to_s)

    # Clear Rails cache before starting
    puts 'Clearing Rails cache...'
    Rails.cache.clear

    # Get all flipper features from database
    db_features = Flipper.features.map(&:name)

    # Find features in DB that are not in features.yml
    unused_features = db_features - defined_features

    puts "Found #{unused_features.count} unused Flipper toggles:"
    unused_features.each { |feature| puts "  - #{feature}" }

    if unused_features.any?
      force_delete = ENV['FORCE'] == 'true'
      should_delete = false

      if force_delete
        puts "\nFORCE=true detected. Deleting all unused toggles without confirmation..."
        should_delete = true
      else
        print "\nDo you want to delete these toggles? (y/N): "
        confirmation = $stdin.gets.chomp.downcase
        should_delete = %w[y yes].include?(confirmation)
      end

      if should_delete
        deleted_count = 0
        failed_count = 0

        unused_features.each do |feature_name|
          # Verify feature exists before deletion
          unless Flipper.exist?(feature_name)
            puts "Skipped: #{feature_name} (doesn't exist)"
            next
          end

          Flipper.remove(feature_name)

          # Validate deletion was successful
          if Flipper.exist?(feature_name)
            puts "❌ Failed: #{feature_name} (still exists after deletion)"
            failed_count += 1
          else
            puts "✅ Deleted: #{feature_name}"
            deleted_count += 1
          end
        rescue => e
          puts "❌ Failed to delete #{feature_name}: #{e.message}"
          failed_count += 1
        end

        puts "\nSummary:"
        puts "- Total unused toggles found: #{unused_features.count}"
        puts "- Successfully deleted: #{deleted_count}"
        puts "- Failed to delete: #{failed_count}"

        if deleted_count.positive?
          puts "\nDeleted toggles:"
          unused_features.each { |feature| puts "  - #{feature}" }
        end
      else
        puts 'Operation cancelled. No toggles were deleted.'
      end
    else
      puts 'No unused Flipper toggles found.'
    end
  end

  desc 'List unused flipper toggles without deleting them'
  task list_unused_toggles: :environment do
    features_file = Rails.root.join('config', 'features.yml')
    features_config = YAML.load_file(features_file)
    defined_features = features_config['features'].keys.map(&:to_s)

    # Clear Rails cache before starting
    puts 'Clearing Rails cache...'
    Rails.cache.clear

    db_features = Flipper.features.map(&:name)
    unused_features = db_features - defined_features

    puts "Unused Flipper toggles (#{unused_features.count}):"
    if unused_features.any?
      unused_features.each { |feature| puts "  - #{feature}" }
    else
      puts '  None found.'
    end
  end
end
