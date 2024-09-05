class DropDataInPersonalInformationLog < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :personal_information_logs, :data, :jsonb }
  end
end
