# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.lockbox_options
    {
      previous_versions: [
        { padding: false },
        { padding: false, master_key: Settings.lockbox.master_key }
      ]
    }
  end

  def self.descendants_using_encryption
    Rails.application.eager_load!
    ApplicationRecord.descendants.select do |model|
      model = model.name.constantize
      model.descendants.empty? &&
        model.respond_to?(:lockbox_attributes) &&
        model.lockbox_attributes.any?
    end
  end
end
