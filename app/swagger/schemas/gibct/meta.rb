# frozen_string_literal: true

module Swagger
  module Schemas
    module Gibct
      class Meta
        include Swagger::Blocks

        STATES = %i[
          AK AL AR AS AZ CA CO CT DC DE FL FM GA GU HI IA
          ID IL IN KS KY LA MA MD ME MH MI MN MO MP MS MT
          NC ND NE BH NJ NM NV NY OH OK OR PA PR PW RI SC
          SD TN TX UT VA VI VT WA WI WV WY
        ].freeze

        swagger_schema :GibctVersion do
          key :type, :object
          key :required, %i[number created_at preview]

          property :number, type: :integer
          property :created_at, type: :string
          property :preview, type: :boolean
        end

        swagger_schema :GibctState do
          key :type, :object
          STATES.each { |state| property state, type: :integer }
        end

        swagger_schema :GibctCountry do
          key :type, :array

          items do
            key :type, :object
            key :required, %i[name count]

            property :name, type: :string
            property :count, type: :integer
          end
        end
      end
    end
  end
end
