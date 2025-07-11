# frozen_string_literal: true

namespace :representation_management do
  namespace :accreditation do
    desc 'Manually reprocess specific Accredited Entity types after validation failure'
    # Usage examples:
    #   rails representation_management:accreditation:reprocess[agents]
    #     # Process only claims agents
    #   rails representation_management:accreditation:reprocess[attorneys]
    #     # Process only attorneys
    #   rails representation_management:accreditation:reprocess[representatives]
    #     # Process only representatives
    #   rails representation_management:accreditation:reprocess[veteran_service_organizations]
    #     # Process only VSOs
    #   rails representation_management:accreditation:reprocess[agents,attorneys]
    #     # Process multiple types
    #   rails representation_management:accreditation:reprocess[representatives,veteran_service_organizations]
    #     # Process reps and VSOs together
    task :reprocess, [:rep_types] => :environment do |_task, args|
      unless args[:rep_types]
        puts 'Error: Please specify representative types to reprocess'
        puts 'Usage: rails representation_management:accreditation:reprocess[agents,attorneys,representatives,' \
             'veteran_service_organizations]'
        exit 1
      end

      rep_types = args[:rep_types].split(',').map(&:strip)
      valid_types = RepresentationManagement::ENTITY_CONFIG.to_h.keys.map(&:to_s)

      invalid_types = rep_types - valid_types
      if invalid_types.any?
        puts "Error: Invalid representative types: #{invalid_types.join(', ')}"
        puts "Valid types are: #{valid_types.join(', ')}"
        exit 1
      end

      puts "Starting manual reprocessing for: #{rep_types.join(', ')}"

      begin
        # Enqueue the job with force_update_types parameter
        RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(rep_types)
        puts "Job enqueued successfully for #{rep_types.join(', ')}"
        puts "Processing #{rep_types.join(', ')} will bypass count validation"
      rescue => e
        puts "Error scheduling reprocessing job: #{e.message}"
        puts e.backtrace.first(10).join("\n")
        exit 1
      end
    end
  end
end
