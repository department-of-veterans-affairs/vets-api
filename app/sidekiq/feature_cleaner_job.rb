# frozen_string_literal: true

class FeatureCleanerJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "FeatureCleanerJob Removing: #{removed_features.join(', ')}"
    # removed_features.each do |feature|
    #   Flipper.remove(feature)
    # end
  end

  private

  def removed_features
    @removed_features ||= Flipper.features.collect(&:name) - FLIPPER_FEATURE_CONFIG['features'].keys
  end
end
