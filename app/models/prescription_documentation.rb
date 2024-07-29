# frozen_string_literal: true

require 'active_model'

class PrescriptionDocumentation
  attr_reader :html

  def initialize(html)
    @html = html
  end
end
