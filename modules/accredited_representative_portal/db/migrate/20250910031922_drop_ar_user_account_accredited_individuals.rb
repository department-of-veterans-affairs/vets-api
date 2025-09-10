# frozen_string_literal: true

class DropArUserAccountAccreditedIndividuals < ActiveRecord::Migration[7.2]
  def change
    safety_assured { drop_table :ar_user_account_accredited_individuals }
  end
end
