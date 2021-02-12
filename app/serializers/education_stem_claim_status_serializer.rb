# frozen_string_literal: true

class EducationStemClaimStatusSerializer < ActiveModel::Serializer
  attributes :id,
             :form,
             :regional_office,
             :confirmation_number,
             :status

  def status
    object.education_stem_automated_decision.automated_decision_state
  end
end
