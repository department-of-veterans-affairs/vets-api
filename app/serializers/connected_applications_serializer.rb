# frozen_string_literal: true

class ConnectedApplicationsSerializer < ActiveModel::Serializer
  attributes :id, :href, :title, :logo, :created, :grants
end
