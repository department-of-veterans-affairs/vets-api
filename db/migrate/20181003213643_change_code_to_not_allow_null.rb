class ChangeCodeToNotAllowNull < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!
  # At this point we shouldn't have any Preference records
  safety_assured

  def change
    # If we did have data, we'd check it first and assign unique values
    # Preference.where(code: nil).each_with_index do |p, i|
      # p.update(code: "unique_code_#{i}")
    # end
    change_column(:preferences, :code, :string, null: false)
  end
end
