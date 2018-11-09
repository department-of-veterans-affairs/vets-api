# frozen_string_literal: true

class Form526JobStatusSerializer < ActiveModel::Serializer
  attribute :job_id
  attribute :status

  def id
    nil
  end
end
