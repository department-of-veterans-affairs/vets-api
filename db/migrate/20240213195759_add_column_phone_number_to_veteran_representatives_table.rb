class AddColumnPhoneNumberToVeteranRepresentativesTable < ActiveRecord::Migration[7.0]
  def change
    add_column :veteran_representatives, :phone_number, :string
  end
end
