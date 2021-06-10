class AddEmailSentAtToEducationStemAutomatedDecision < ActiveRecord::Migration[6.0]
  def change
    add_column :education_stem_automated_decisions, :denial_email_sent_at, :timestamp
    add_column :education_stem_automated_decisions, :confirmation_email_sent_at, :timestamp
  end
end
