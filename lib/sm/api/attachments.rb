# frozen_string_literal: true
require 'common/models/collection'

module SM
  module API
    module Attachments
      # get_attachment retrieves the attachment for a message
      def get_attachment(message_id, attachment_id)
        path = "message/#{message_id}/attachment/#{attachment_id}"
        perform(:get, path, nil, token_headers)
      end
    end
  end
end
