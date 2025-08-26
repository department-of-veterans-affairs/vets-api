# frozen_string_literal: true

# Test migration demonstrating human judgment issues in veteran data schema changes
# These issues require understanding business context and impact on live veteran services

class AddVeteranBenefitsTracking < ActiveRecord::Migration[7.0]
  def change
    # HUMAN JUDGMENT: Adding sensitive veteran data columns
    # Requires understanding of PII implications and VA data handling requirements
    add_column :veterans, :disability_percentage, :integer
    add_column :veterans, :service_connected_conditions, :text
    
    # HUMAN JUDGMENT: Mixing index changes with schema changes
    # This locks the veterans table during deployment, affecting live services
    add_index :veterans, :disability_percentage
    
    # HUMAN JUDGMENT: Index on frequently queried field without considering load
    # Veterans table has 10M+ records, this will cause extended downtime
    add_column :veterans, :benefit_eligibility_status, :string
    add_index :veterans, :benefit_eligibility_status
    
    # HUMAN JUDGMENT: Missing consideration for existing veteran records
    # This change affects existing claims processing without data migration strategy
    change_column_null :veterans, :service_branch, false
  end
end
