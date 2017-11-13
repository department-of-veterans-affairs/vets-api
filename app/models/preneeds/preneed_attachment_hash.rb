# frozen_string_literal: true
module Preneeds
  class PreneedAttachmentHash < Preneeds::Base
    attribute :confirmation_code, String
    attribute :attachment_id, String

    def self.permitted_params
      [:confirmation_code, :attachment_id]
    end
  end
end
