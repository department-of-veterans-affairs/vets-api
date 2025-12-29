# frozen_string_literal: true

class AddSentToCorpdbAtToPowerOfAttorneyRequests < ActiveRecord::Migration[7.1]
    def change
      add_column :ar_power_of_attorney_requests, :sent_to_corpdb_at, :datetime
    end
end
  
  