class AddLastSha256ChangeToVAFormsForms < ActiveRecord::Migration[7.0]
  def change
    add_column :va_forms_forms, :last_sha256_change, :date
  end
end
