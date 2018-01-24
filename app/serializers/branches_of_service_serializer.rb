# frozen_string_literal: true

class BranchesOfServiceSerializer < ActiveModel::Serializer
  attribute :id

  attribute(:branches_of_service_id) { object.id }
  attribute :code
  attribute :begin_date
  attribute :end_date
  attribute :flat_full_descr
  attribute :full_descr
  attribute :short_descr
  attribute :state_required
  attribute :upright_full_descr
end
