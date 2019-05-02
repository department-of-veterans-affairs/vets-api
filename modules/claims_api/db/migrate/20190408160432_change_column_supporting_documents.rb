# frozen_string_literal: true

class ChangeColumnSupportingDocuments < ActiveRecord::Migration
  def change
    remove_column :claims_api_supporting_documents, :auto_established_claim_id, :integer, null: false
    add_column :claims_api_supporting_documents, :auto_established_claim_id, :uuid
  end
end
