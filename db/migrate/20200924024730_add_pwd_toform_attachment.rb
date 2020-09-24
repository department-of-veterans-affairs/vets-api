class AddPwdToformAttachment < ActiveRecord::Migration[6.0]
  def change
    add_column :form_attachments, :encrypted_file_password, :string
    add_column :form_attachments, :encrypted_file_password_iv, :string
  end
end
