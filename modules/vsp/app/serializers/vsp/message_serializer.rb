# frozen_string_literal: true

module Vsp
  class MessageSerializer
    include FastJsonapi::ObjectSerializer
    attributes :message
  end
end
