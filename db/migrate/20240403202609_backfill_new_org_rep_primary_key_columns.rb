# frozen_string_literal: true

class BackfillNewOrgRepPrimaryKeyColumns < ActiveRecord::Migration[7.1]
  def change
    def up
      AccreditedRepresentative.find_each do |rep|
        rep.update_column(:representative_id, rep.number)
      end
  
      AccreditedOrganization.find_each do |org|
        org.update_column(:poa_code, org.poa)
      end
    end
  
    def down
      AccreditedRepresentative.update_all(representative_id: nil)
      AccreditedOrganization.update_all(poa_code: nil)
    end
  end
end
