# frozen_string_literal: true 

module Identity 
  class Phone 
    include Virtus::Model

    attribute :number, String
    attribute :kind,   String
  end
end