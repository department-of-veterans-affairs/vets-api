# frozen_string_literal: true

module Swagger
  module Schemas
    module Gibct
      class InstitutionPrograms
        include Swagger::Blocks

        STATES = %i[
          AK AL AR AS AZ CA CO CT DC DE FL FM GA GU HI IA
          ID IL IN KS KY LA MA MD ME MH MI MN MO MP MS MT
          NC ND NE BH NJ NM NV NY OH OK OR PA PR PW RI SC
          SD TN TX UT VA VI VT WA WI WV WY
        ].freeze

        swagger_schema :GibctInstitutionProgramsAutocomplete do
          key :required, %i[data meta links]

          property :data, type: :array, minItems: 0, uniqueItems: true do
            items do
              property :id, type: :integer
              property :value, type: :string
              property :label, type: :string
            end
          end

          property :meta, '$ref': :GibctInstitutionProgramsAutocompleteMeta

          property :links, type: :object do
            property :self, type: :string
          end
        end

        swagger_schema :GibctInstitutionProgramsSearch do
          key :required, %i[data meta links]

          property :data, type: :array, maxItems: 10, uniqueItems: true do
            items do
              key :type, :object
              key :required, %i[id type attributes]

              property :id, type: :string
              property :type, type: :string, enum: ['institution_programs']
              property :attributes do
                key :required, %i[facility_code description]

                property :program_type, type: :string,
                                        enum: %w[IHL NCD OJT FLGT CORR]
                property :description, type: :string
                property :length_in_hours, type: :string
                property :facility_code, type: :string
                property :institution_name, type: :string
                property :city, type: :string
                property :state, type: :string
                property :country, type: :string
                property :preferred_provider, type: :boolean
                property :tuition_amount, type: :integer
                property :va_bah, type: :number
                property :dod_bah, type: :integer
              end
            end
          end

          property :meta, '$ref': :GibctInstitutionProgramsSearchMeta
          property :links, '$ref': :GibctInstitutionProgramsSearchLinks
        end

        swagger_schema :GibctInstitutionProgramsAutocompleteMeta do
          key :type, :object
          key :required, %i[version term]

          property :version, type: :object do
            key :required, %i[number created_at preview]

            property :number, type: :integer
            property :created_at, type: :string
            property :preview, type: :boolean
          end
          property :term, type: :string
        end

        swagger_schema :GibctInstitutionProgramsSearchMeta do
          key :type, :object
          key :required, %i[version count facets]

          property :version, type: :object do
            key :required, %i[number created_at preview]

            property :number, type: :integer
            property :created_at, type: :string
            property :preview, type: :boolean
          end

          property :count, type: :integer
          property :facets, type: :object do
            key :required, %i[type state country]
            property :type, type: :object do
              property :ihl, type: :integer
              property :ncd, type: :integer
              property :ojt, type: :integer
              property :flgt, type: :integer
              property :corr, type: :integer
            end

            property :state, type: :object do
              STATES.each { |state| property state, type: :integer }
            end

            property :country, type: :array do
              items do
                key :type, :object
                key :required, %i[name count]

                property :name, type: :string
                property :count, type: :integer
              end
            end
          end
        end

        swagger_schema :GibctInstitutionProgramsSearchLinks do
          key :type, :object
          key :required, %i[self first prev next last]

          property :self, type: :string
          property :first, type: :string
          property :prev, type: %i[null string]
          property :next, type: %i[null string]
          property :last, type: :string
        end
      end
    end
  end
end
