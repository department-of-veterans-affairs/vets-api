# frozen_string_literal: true
class LetterBeneficiarySerializer < ActiveModel::Serializer
  attribute :benefit_information
  attribute :military_service
  attribute :has_adapted_housing
  attribute :has_chapter35_eligibility
  attribute :has_death_result_of_disability
  attribute :has_individual_unemployability_granted
  attribute :has_special_monthly_compensation

  def id
    nil
  end
end
