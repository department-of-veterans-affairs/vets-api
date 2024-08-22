class AddFuzzystrmatchExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'fuzzystrmatch'
  end
end
