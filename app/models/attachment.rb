# frozen_string_literal: true
require 'common/models/base'

# Attachment model
class Attachment < Common::Base
  attribute :id, String
  attribute :message_id, String
  attribute :name, String

  def <=>(other)
    id <=> other.id
  end
end
