# frozen_string_literal: true

# TEST FILE: Example of model changes for column rename
# For testing the MigrationIsolator Dangerfile changes
# DO NOT MERGE THIS FILE - For testing only

class SavedClaimTest < ApplicationRecord
  self.table_name = 'saved_claims'
  
  # Strong Migrations pattern: provide backwards compatibility during rename
  alias_attribute :user_uuid, :user_account_uuid
  
  # Or alternatively, if gradually migrating:
  # self.ignored_columns += %w[user_uuid]
  
  belongs_to :user_account, optional: true
  
  validates :form_id, presence: true
  validates :user_account_uuid, presence: true
  
  # Rest of model code...
end