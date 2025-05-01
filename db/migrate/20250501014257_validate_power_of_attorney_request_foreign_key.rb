class ValidatePowerOfAttorneyRequestForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :ar_power_of_attorney_request_decisions, :ar_power_of_attorney_requests
  end
end
