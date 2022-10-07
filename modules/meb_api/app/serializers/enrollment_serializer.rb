# frozen_string_literal: true

class EnrollmentSerializer < ActiveModel::Serializer
  attribute :enrollment_verifications
  attribute :last_certified_through_date
  attribute :payment_on_hold

  def id
    nil
  end
end
