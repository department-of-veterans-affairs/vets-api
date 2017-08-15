class MoveEducationBenefitsToSavedClaims < ActiveRecord::Migration
  def change
    add_reference(:education_benefits_claims, :saved_claim, index: true)
    add_column(:saved_claim, :education_benefits_claim_id, :integer)

    insert_sql = <<-sql
      INSERT INTO saved_claims
        (encrypted_form, encrypted_form_iv, type, form_id, education_benefits_claim_id)
      SELECT
        encrypted_form,
        encrypted_form_iv,
        concat('SavedClaim::EducationBenefits::VA', form_type),
        concat('22-', upper(form_type)),
        id
      FROM education_benefits_claims
      RETURNING id, education_benefits_claim_id
      WHERE education_benefits_claims.id = 1
    sql
    sql = <<-sql
      WITH inserted AS (#{insert_sql})
      UPDATE education_benefits_claim
      SET saved_claim_id = inserted.id
      FROM inserted
      WHERE education_benefits_claim.id = inserted.education_benefits_claim_id
    sql

    ActiveRecord::Base.connection.execute(sql)

    # EducationBenefitsClaim.find_each do |education_benefits_claim|
    #   form_type = education_benefits_claim.read_attribute(:form_type)

    #   education_benefits_claim.saved_claim = SavedClaim::EducationBenefits.form_class(form_type).new(
    #     encrypted_form: education_benefits_claim.read_attribute(:encrypted_form),
    #     encrypted_form_iv: education_benefits_claim.read_attribute(:encrypted_form_iv)
    #   )

    #   education_benefits_claim.save!
    # end

    change_column_null(:education_benefits_claims, :saved_claim_id, false)

    %w(submitted_at encrypted_form encrypted_form_iv form_type).each do |attr|
      change_column_null(:education_benefits_claims, attr, true)
      rename_column(:education_benefits_claims, attr, "_#{attr}")
    end

    add_index(:education_benefits_claims, :created_at)
  end
end
