# frozen_string_literal: true

class AddStatusToNoticeOfDisagreements < ActiveRecord::Migration[6.0]
  def change
    safety_assured do
      add_column :appeals_api_notice_of_disagreements, :status, :string, null: false, default: 'pending'
    end
  end
end
