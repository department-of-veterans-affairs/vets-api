# frozen_string_literal: true

class DependentSerializer < ActiveModel::Serializer
  type :dependent

  attributes(:award_indicator,
             :city_of_birth,
             :date_of_birth,
             :email_address,
             :first_name,
             :gender,
             :last_name,
             :middle_name,
             :ptcpnt_id,
             :related_to_vet,
             :relationship,
             :ssn,
             :ssn_verify_status,
             :state_of_birth,
             :veteran_indicator,
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
