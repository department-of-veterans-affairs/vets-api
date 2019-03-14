# frozen_string_literal: true

class CreateVeteranServiceObjects < ActiveRecord::Migration
    def change
      create_table :veteran_service_organizations do |t|
        

        t.timestamps null: false
      end

      create_table :veteran_service_representatives do |t|
        

        t.timestamps null: false
      end
    end
  end
  