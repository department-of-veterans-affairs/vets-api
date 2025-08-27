# frozen_string_literal: true

require 'vets/model'

module VAProfile
  module Models
    class Base
      include Vets::Model

      SOURCE_SYSTEM = 'VETSGOV'
    end
  end
end
