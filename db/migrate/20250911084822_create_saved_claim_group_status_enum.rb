# frozen_string_literal: true

class CreateSavedClaimGroupStatusEnum < ActiveRecord::Migration[7.2]
  def change
    create_enum :saved_claim_group_status, %w[pending accepted failure processing success]
  end
end
