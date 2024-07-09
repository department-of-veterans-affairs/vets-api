# frozen_string_literal: true

require 'active_model'

class PrescriptionDocumentation
  attr_reader :data

  def initialize(data)
    @data = data
  end
end
