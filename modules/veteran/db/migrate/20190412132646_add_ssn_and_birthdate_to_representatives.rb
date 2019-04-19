# frozen_string_literal: true

class AddSsnAndBirthdateToRepresentatives < ActiveRecord::Migration[5.0]
  def change
    add_column :veteran_representatives, :encrypted_ssn, :string
    add_column :veteran_representatives, :encrypted_ssn_iv, :string
    add_column :veteran_representatives, :encrypted_dob, :string
    add_column :veteran_representatives, :encrypted_dob_iv, :string
  end
end
