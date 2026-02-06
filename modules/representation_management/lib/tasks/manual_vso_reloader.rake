# frozen_string_literal: true

# In production terminal console run:
# bundle exec rake representation_management:reload_representation_management_vso
namespace :representation_management do
  desc 'Manually run the VSO reloader job (synchronously)'
  task reload_representation_management_vso: :environment do
    Rails.logger.info('[rake] Starting RepresentationManagement::VSOReloader')

    RepresentationManagement::VSOReloader.new.perform

    Rails.logger.info('[rake] Finished RepresentationManagement::VSOReloader')
    puts 'VSOReloader finished successfully'
  rescue => e
    Rails.logger.error("[rake] VSOReloader failed: #{e.class}: #{e.message}")
    raise e
  end
end
