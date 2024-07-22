# frozen_string_literal: true

class EducationStemClaimStatusSerializer
  include JSONAPI::Serializer

  attribute :confirmation_number

  attribute :is_enrolled_stem do |object|
    object.saved_claim.parsed_form['isEnrolledStem']
  end

  attribute :is_pursuing_teaching_cert do |object|
    object.saved_claim.parsed_form['isPursuingTeachingCert']
  end

  attribute :benefit_left do |object|
    object.saved_claim.parsed_form['benefitLeft']
  end

  attribute :remaining_entitlement do |object|
    object.education_stem_automated_decision.remaining_entitlement
  end

  attribute :automated_denial do |object|
    object.education_stem_automated_decision.automated_decision_state == 'denied'
  end

  attribute :denied_at do |object|
    next nil if object.education_stem_automated_decision.automated_decision_state != 'denied'

    object.education_stem_automated_decision.updated_at
  end

  attribute :submitted_at, &:created_at
end
