# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.lockbox_options
    { previous_versions: [master_key: Settings.lockbox.previous_master_key] }
  end
end
