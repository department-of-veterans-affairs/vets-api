# frozen_string_literal: true

class AddDoctypeAndDescription < ActiveRecord::Migration
    def change
      add_column :claims_api_supporting_documents, :document_type, :string
      add_column :claims_api_supporting_documents, :description, :string
    end
  end
