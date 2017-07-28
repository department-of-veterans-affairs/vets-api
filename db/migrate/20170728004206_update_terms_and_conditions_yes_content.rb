class UpdateTermsAndConditionsYesContent < ActiveRecord::Migration
  def up
    yes_content = 'Yes, I agree with the terms and conditions for medical information'
    terms_and_conditions = TermsAndConditions.find_by(version: '1.0')
    terms_and_conditions.yes_content = yes_content
    terms_and_conditions.save!
  end

  def down
    yes_content = 'Yes I agree with the terms and conditions for medical information'
    terms_and_conditions = TermsAndConditions.find_by(version: '1.0')
    terms_and_conditions.yes_content = yes_content
    terms_and_conditions.save!
  end
end
