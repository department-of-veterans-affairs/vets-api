# frozen_string_literal: true

module Swagger
  module Schemas
    module Gibct
      class InstitutionPrograms
        include Swagger::Blocks

        swagger_schema :GibctInstitutionProgramsAutocomplete do
          key :required, %i[data meta links]

          property :data, type: :array, minItems: 0, uniqueItems: true do
            items do
              property :id, type: :integer, example: '1234'
              property :value, type: :string, example: '1X12345'
              property :label, type: :string, example: 'COMPUTER SCIENCE'
            end
          end

          property :meta, '$ref': :GibctInstitutionProgramsAutocompleteMeta

          property :links, type: :object do
            property :self, type: :string, example: 'http://localhost:3000/v0/institution_programs/autocomplete?name=code'
          end
        end

        swagger_schema :GibctInstitutionProgramsSearch do
          key :required, %i[data meta links]

          property :data, type: :array, maxItems: 10, uniqueItems: true do
            items do
              key :type, :object
              key :required, %i[id type attributes]

              property :id, type: :string, example: '1973-01-01T05:00:00.000+00:00'
              property :type, type: :string, enum: ['institution_programs']
              property :attributes do
                key :required, %i[facility_code description]

                property :program_type, type: %i[null string],
                                        enum: %w[IHL NCD OJT FLGT CORR]
                property :description, type: :string, example: 'COMPUTER SCIENCE'
                property :length_in_hours, type: %i[null string], example: '680'
                property :length_in_weeks, type: %i[null integer], example: 12
                property :facility_code, type: :string, example: '1X12345'
                property :institution_name, type: :string, example: 'CODE PLACE'
                property :city, type: %i[null string], example: 'ANYTOWN'
                property :state, type: %i[null string], example: 'WA'
                property :country, type: %i[null string], example: 'USA'
                property :preferred_provider, type: %i[null boolean], example: false
                property :tuition_amount, type: %i[null integer], example: 1000
                property :va_bah, type: %i[null number], example: 220
                property :dod_bah, type: %i[null integer], example: 200
              end
            end
          end

          property :meta, '$ref': :GibctInstitutionProgramsSearchMeta
          property :links, '$ref': :GibctInstitutionProgramsSearchLinks
        end

        swagger_schema :GibctInstitutionProgramsAutocompleteMeta do
          key :type, :object
          key :required, %i[version term]

          property :version, '$ref': :GibctVersion
          property :term, type: :string, example: 'code'
        end

        swagger_schema :GibctInstitutionProgramsSearchMeta do
          key :type, :object
          key :required, %i[version count facets]

          property :version, '$ref': :GibctVersion

          property :count, type: :integer, example: 1
          property :facets, type: :object do
            key :required, %i[type state country]
            property :type, type: :object do
              property :ihl, type: :integer, example: 0
              property :ncd, type: :integer, example: 1
              property :ojt, type: :integer, example: 0
              property :flgt, type: :integer, example: 0
              property :corr, type: :integer, example: 0
            end

            property :state, '$ref': :GibctState
            property :country, '$ref': :GibctCountry
          end
        end

        swagger_schema :GibctInstitutionProgramsSearchLinks do
          key :type, :object
          key :required, %i[self first prev next last]

          property :self, type: :string, example: 'http://localhost:3000/v0/institution_programs/?name=code'
          property :first, type: :string
          property :prev, type: %i[null string]
          property :next, type: %i[null string]
          property :last, type: :string, example: 'http://localhos:3000/v0/institution_programs/?name=code&page=3&per_page=30'
        end
      end
    end
  end
end
