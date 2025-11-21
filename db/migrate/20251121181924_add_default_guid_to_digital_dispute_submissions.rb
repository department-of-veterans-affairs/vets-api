# frozen_string_literal: true

class AddDefaultGuidToDigitalDisputeSubmissions < ActiveRecord::Migration[7.2]
  def change
    change_column_default :digital_dispute_submissions, :guid, from: nil, to: -> { 'gen_random_uuid()' }
  end
end
