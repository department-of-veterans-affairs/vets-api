class EduBenefitsDataMigration < ActiveRecord::Migration
  def change
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
        uuid_generate_v4()
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
  end
end
