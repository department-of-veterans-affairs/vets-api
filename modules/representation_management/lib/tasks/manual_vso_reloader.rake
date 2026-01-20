# lib/tasks/representation_management/vso_reloader.rake
# frozen_string_literal: true

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
