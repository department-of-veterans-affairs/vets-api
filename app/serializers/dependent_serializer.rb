# frozen_string_literal: true

class DependentSerializer < ActiveModel::Serializer
  type :dependent

  attributes(:awardIndicator,
             :cityOfBirth,
             :dateOfBirth,
             :emailAddress,
             :firstName,
             :gender,
             :lastName,
             :middleName,
             :ptcpntId,
             :relatedToVet,
             :relationship,
             :ssn,
             :ssnVerifyStatus,
             :stateOfBirth,
             :veteranIndicator,
             :dependent_benefit_type)

  def id
    nil
  end

  def upcoming_removal_date
    object.dig(:upcoming_removal, :award_effective_date)
  end

  def upcoming_removal_reason
    object.dig(:upcoming_removal, :dependency_status_type_description).gsub(/\s+/, ' ')
  end
end
