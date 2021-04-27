class AddBoardReviewOptionToNoticeOfDisagreement < ActiveRecord::Migration[6.0]
  def change
    add_column :appeals_api_notice_of_disagreements, :board_review_option, :string
  end
end
