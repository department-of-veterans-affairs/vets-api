# frozen_string_literal: true

class ChangeColumnSupportingDocuments < ActiveRecord::Migration
  def up
    change_column :claims_api_supporting_documents, :auto_established_claim_id, :uuid
  end

  def up
    change_column :claims_api_supporting_documents, :auto_established_claim_id, :integer
  end
end
  