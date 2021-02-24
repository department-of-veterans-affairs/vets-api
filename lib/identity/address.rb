# frozen_string_literal: true 

module Identity 
  class Address 

    KINDS = ['home', 'work', 'other']

    include Virtus::Model



    attribute :street,      String
    attribute :street2,     String
    attribute :city,        String
    attribute :subdivision, String
    attribute :postal_code, String
    attribute :country,     String
    attribute :kind,        String

    validates :kind, inclusion: { in: KINDS }
    validates :street, presence: true
    validates :postal_code, presence: true
  end
end