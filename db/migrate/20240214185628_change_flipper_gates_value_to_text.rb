class ChangeFlipperGatesValueToText < ActiveRecord::Migration[7.0]
  def change
    change_column :flipper_gates, :value, :text
  end
end
