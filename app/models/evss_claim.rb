# frozen_string_literal: true

require 'evss/documents_service'

class EVSSClaim < ApplicationRecord
  include UserIdentifiable
end
