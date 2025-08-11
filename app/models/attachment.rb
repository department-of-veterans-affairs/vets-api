# frozen_string_literal: true

require 'vets/model'

# Attachment model
class Attachment
  include Vets::Model

  attribute :id, Integer
  attribute :message_id, Integer
  attribute :name, String
  attribute :attachment_size, Integer
  attribute :metadata, Hash, default: -> { {} }
end
