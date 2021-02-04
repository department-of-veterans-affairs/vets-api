class AddDetailToNoticeOfDisagreement < ActiveRecord::Migration[6.0]
  def change
    add_column :appeals_api_notice_of_disagreements, :detail, :string
  end
end
