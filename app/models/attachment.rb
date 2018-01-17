# frozen_string_literal: true

require 'common/models/base'

# Attachment model
class Attachment < Common::Base
  attribute :id, Integer
  attribute :message_id, Integer
  attribute :name, String
end
