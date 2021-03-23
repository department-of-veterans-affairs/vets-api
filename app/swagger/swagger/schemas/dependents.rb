# frozen_string_literal: true

module Swagger
  module Schemas
    class Dependents
      include Swagger::Blocks

      swagger_schema :Dependents do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :persons do
              items do
                key :type, :object
                key :'$ref', :Persons
              end
            end
          end
        end
      end

      swagger_schema :Persons do
        key :required, %i[award_indicator]
        property :award_indicator, type: :string, example: 'N'
        property :city_of_birth, type: :string, example: 'WASHINGTON'
        property :current_relate_status, type: :string, example: nil
        property :date_of_birth, type: :string, example: '01/01/2000'
        property :date_of_death, type: :string, example: nil
        property :death_reason, type: :string, example: nil
        property :email_address, type: :string, example: 'Curt@email.com'
        property :first_name, type: :string, example: 'CURT'
        property :last_name, type: :string, example: 'WEBB-STER'
        property :middle_name, type: :string, example: nil
        property :proof_of_dependency, type: :string, example: 'Y'
        property :ptcpnt_id, type: :string, example: '32354974'
        property :related_to_vet, type: :string, example: 'N'
        property :relationship, type: :string, example: 'Child'
        property :ssn, type: :string, example: '500223351'
        property :ssn_verify_status, type: :string, example: '1'
        property :state_of_birth, type: :string, example: 'DC'
      end
    end
  end
end
