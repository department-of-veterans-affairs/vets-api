class ZipcodeDataTypeToString < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      change_column :std_zipcodes, :zip_code, :string
    end
  end

  def down
    safety_assured do
      change_column :std_zipcodes, :zip_code, :integer
    end
  end
end
