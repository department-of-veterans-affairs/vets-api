# frozen_string_literal: true

class EducationStemClaimStatusSerializer < ActiveModel::Serializer
  attributes :confirmation_number,
             :is_enrolled_stem,
             :is_pursuing_teaching_cert,
             :benefit_left,
             :remaining_entitlement,
             :automated_denial,
             :denied_at,
             :submitted_at

  # rubocop:disable Naming/PredicateName
  def is_enrolled_stem
    object.saved_claim.parsed_form['isEnrolledStem']
  end

  def is_pursuing_teaching_cert
    object.saved_claim.parsed_form['isPursuingTeachingCert']
  end
  # rubocop:enable Naming/PredicateName

  def benefit_left
    object.saved_claim.parsed_form['benefitLeft']
  end

  def remaining_entitlement
    object.education_stem_automated_decision.remaining_entitlement
  end

  def automated_denial
    object.education_stem_automated_decision.automated_decision_state == 'denied'
  end

  def denied_at
    return nil if object.education_stem_automated_decision.automated_decision_state != 'denied'

    object.education_stem_automated_decision.updated_at
  end

  def submitted_at
    object.created_at
  end
end
