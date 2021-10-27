# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.lockbox_options
    { previous_versions: [{ padding: true, master_key: Settings.lockbox.master_key }] }
  end
end
