# frozen_string_literal: true

# NOT USING JSON:API Specification
# app/controllers/v0/disability_compensation_forms_controller.rb
class EVSSSeparationLocationSerializer < ActiveModel::Serializer
  attribute :separation_locations

  def id
    nil
  end
end
