# frozen_string_literal: true

namespace :veteran do
  namespace :accreditation do
    desc 'Manually reprocess specific representative types after validation failure'
    # IMPORTANT: VSO representatives and organizations are always processed together to maintain data integrity.
    # If you specify only 'vso_representatives' or only 'vso_organizations', BOTH will be processed automatically.
    # This prevents VSO representatives from having broken references to their organizations.
    #
    # Examples:
    #   rails veteran:accreditation:reprocess[attorneys]                   # Processes only attorneys
    #   rails veteran:accreditation:reprocess[vso_representatives]         # Processes BOTH reps and orgs
    #   rails veteran:accreditation:reprocess[vso_organizations]           # Processes BOTH reps and orgs
    #   rails veteran:accreditation:reprocess[attorneys,vso_organizations] # Processes attorneys, reps, and orgs
    task :reprocess, [:rep_types] => :environment do |_task, args|
      unless args[:rep_types]
        puts 'Error: Please specify representative types to reprocess'
        puts 'Usage: rails veteran:accreditation:reprocess[attorneys,claims_agents,vso_representatives,vso_organizations]' # rubocop:disable Layout/LineLength
        puts 'Note: VSO representatives and organizations must be processed together'
        exit 1
      end

      rep_types = args[:rep_types].split(',').map(&:strip).map(&:to_sym)
      valid_types = %i[attorneys claims_agents vso_representatives vso_organizations]

      invalid_types = rep_types - valid_types
      if invalid_types.any?
        puts "Error: Invalid representative types: #{invalid_types.join(', ')}"
        puts "Valid types are: #{valid_types.join(', ')}"
        exit 1
      end

      # Ensure VSO types are processed together
      vso_types = %i[vso_representatives vso_organizations]
      # Check if user specified any VSO type but not both
      has_vso = if rep_types.respond_to?(:intersect?)
                  rep_types.intersect?(vso_types)
                else
                  (rep_types & vso_types).any? # rubocop:disable Style/ArrayIntersect
                end
      has_both_vso = (rep_types & vso_types).sort == vso_types.sort

      if has_vso && !has_both_vso
        puts '=' * 80
        puts 'IMPORTANT: VSO representatives and organizations must be processed together.'
        puts 'You specified only one VSO type, but BOTH will be processed to maintain data integrity.'
        puts 'This prevents VSO representatives from having broken references to their organizations.'
        puts '=' * 80
        # Ensure consistent ordering by removing any existing VSO types and adding both in order
        rep_types = rep_types - vso_types + vso_types
      end

      puts "Starting manual reprocessing for: #{rep_types.join(', ')}"

      # Create a custom reloader instance that only processes specific types
      reloader = Veteran::VSOReloader.new
      reloader.instance_variable_set(:@manual_reprocess_types, rep_types)

      # Override validation for manual reprocessing
      reloader.define_singleton_method(:valid_count?) do |rep_type, new_count|
        if @manual_reprocess_types.include?(rep_type)
          puts "Manual override: Processing #{rep_type} with count #{new_count}"
          @validation_results[rep_type] = new_count
          true
        else
          super(rep_type, new_count)
        end
      end

      begin
        reloader.perform
        puts 'Reprocessing completed successfully'
      rescue => e
        puts "Error during reprocessing: #{e.message}"
        puts e.backtrace.first(10).join("\n")
        exit 1
      end
    end
  end
end
