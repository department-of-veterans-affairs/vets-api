class MoveEducationBenefitsToSavedClaims < ActiveRecord::Migration
  def change
    add_reference(:education_benefits_claims, :saved_claim, index: true)
    add_column(:saved_claims, :education_benefits_claim_id, :integer)

    # form_type is `1990 1995 1990e 5490 5495 1990n` all lowercase
    insert_sql = <<-sql
      INSERT INTO saved_claims
        (encrypted_form, encrypted_form_iv, type, form_id, education_benefits_claim_id, guid)
      SELECT
        encrypted_form,
        encrypted_form_iv,
        concat('SavedClaim::EducationBenefits::VA', form_type),
        concat('22-', upper(form_type)),
        id,
        #{ActiveRecord::Base::sanitize(SecureRandom.uuid)}
      FROM education_benefits_claims
      RETURNING id, education_benefits_claim_id
    sql
    sql = <<-sql
      WITH inserted AS (#{insert_sql})
      UPDATE education_benefits_claims
      SET saved_claim_id = inserted.id
      FROM inserted
      WHERE education_benefits_claims.id = inserted.education_benefits_claim_id
    sql

    ActiveRecord::Base.connection.execute(sql)

    remove_column(:saved_claims, :education_benefits_claim_id)

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
