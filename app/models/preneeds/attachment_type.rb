# frozen_string_literal: true'
require 'common/models/base'

module Preneeds
  class AttachmentType  < Common::Base
    attribute :attachment_type_id, Integer
    attribute :description, String # OPTIONAL
  end
end
