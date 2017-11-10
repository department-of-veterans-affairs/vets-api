# frozen_string_literal: true
module Preneeds
  class PreneedAttachmentHash < Preneeds::Base
    attribute :confirmation_code, String
    attribute :attachment_id, String
  end
end
