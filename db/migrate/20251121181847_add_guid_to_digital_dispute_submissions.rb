# frozen_string_literal: true

class AddGuidToDigitalDisputeSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :digital_dispute_submissions, :guid, :uuid
  end
end
