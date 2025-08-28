# frozen_string_literal: true

require 'vets/model'

module VAProfile
  module Models
    class Base
      include Vets::Model

      SOURCE_SYSTEM = 'VETSGOV'

      alias to_h attributes
      alias to_hash attributes
    end
  end
end
