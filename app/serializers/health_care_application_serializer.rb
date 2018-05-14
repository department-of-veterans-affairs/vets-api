# frozen_string_literal: true

class HealthCareApplicationSerializer < ActiveModel::Serializer
  attributes :id, :state, :form_submission_id, :timestamp
end
