# frozen_string_literal: true

module Form1010cg
  class AttachmentSerializer < ActiveModel::Serializer
    attribute :guid
    attribute :created_at

    def id
      nil
    end
  end
end
