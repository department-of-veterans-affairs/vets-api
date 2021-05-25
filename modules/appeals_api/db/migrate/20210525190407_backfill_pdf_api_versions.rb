class BackfillPdfApiVersions < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    AppealsApi::HigherLevelReview.unscoped.in_batches do |relation|
      relation.update_all(pdf_fill_version: 'V1', api_version: 'V1')
      sleep(0.01) # throttle
    end

    AppealsApi::NoticeOfDisagreement.unscoped.in_batches do |relation|
      relation.update_all(pdf_fill_version: 'V1', api_version: 'V1')
      sleep(0.01) # throttle
    end
  end

  def down
  end
end
