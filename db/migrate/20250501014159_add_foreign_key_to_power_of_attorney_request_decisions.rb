class AddForeignKeyToPowerOfAttorneyRequestDecisions < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :ar_power_of_attorney_request_decisions,
                    :ar_power_of_attorney_requests,
                    column: :power_of_attorney_request_id,
                    validate: false
  end
end
