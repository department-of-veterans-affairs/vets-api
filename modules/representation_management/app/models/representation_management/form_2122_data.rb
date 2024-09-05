# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    attr_accessor :organization_name

    validates :organization_name, presence: true
  end
end
