class ModifyMhvAcTermsContent < ActiveRecord::Migration[4.2]
  def terms_and_conditions
    TermsAndConditions.find_by(name: 'mhvac', version: '1.0')
  end

  def up
    yes_content = 'Yes, I agree with the terms and conditions for medical information'

    tc = terms_and_conditions

    if tc
      tc.header_content.gsub! 'vets.gov', 'Vets.gov'
      tc.yes_content = yes_content
      tc.save!
    end
  end

  def down
    yes_content = 'Yes I agree with the terms and conditions for medical information'

    tc = terms_and_conditions

    if tc
      tc.header_content.gsub! 'Vets.gov', 'vets.gov'
      tc.yes_content = yes_content
      tc.save!
    end
  end
end
