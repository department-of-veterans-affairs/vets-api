# frozen_string_literal: true

class LighthouseRatingInfoSerializer < ActiveModel::Serializer
  attributes :user_percent_of_disability, :source_system

  def id
    nil
  end

  def source_system
    'Lighthouse'
  end

  def read_attribute_for_serialization(attr)
    respond_to?(attr) ? send(attr) : object[attr]
  end
end
