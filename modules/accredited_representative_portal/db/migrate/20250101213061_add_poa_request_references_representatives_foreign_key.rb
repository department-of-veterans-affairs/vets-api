class AddPoaRequestReferencesRepresentativesForeignKey < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :ar_power_of_attorney_requests, :accredited_individuals, validate: false
  end
end
