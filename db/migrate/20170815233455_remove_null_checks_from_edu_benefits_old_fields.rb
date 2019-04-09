class RemoveNullChecksFromEduBenefitsOldFields < ActiveRecord::Migration[4.2]
  def change
    %w(submitted_at encrypted_form encrypted_form_iv form_type).each do |attr|
      change_column_null(:education_benefits_claims, attr, true)
    end
  end
end
