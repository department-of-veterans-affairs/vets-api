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
<<<<<<< HEAD
              property :id, type: :integer, example: 1234
              property :value, type: :string, example: '1X12345'
              property :label, type: :string, example: 'COMPUTER SCIENCE'
=======
              property :id, type: :integer, example: '1234', description: 'Unique program ID'
              property :value, type: :string, example: '1X12345', description: 'Program institution facility code'
              property :label, type: :string, example: 'COMPUTER SCIENCE', description: 'Program name'
>>>>>>> 968f85cf52233cff7241b204a69588bc17794d43
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

<<<<<<< HEAD
                property :program_type, type: %i[null string],
                                        enum: %w[IHL NCD OJT FLGT CORR],
=======
                property :program_type, type: %i[null string], enum: %w[IHL NCD OJT FLGT CORR],
>>>>>>> 968f85cf52233cff7241b204a69588bc17794d43
                                        description: 'The classification of the program, ex: IHL, NCD, OJT'
                property :description, type: :string, example: 'COMPUTER SCIENCE',
                                       description: 'Program name'
                property :length_in_hours, type: %i[null string], example: '680',
                                           description: 'Length of program (in hours)'
                property :length_in_weeks, type: %i[null integer], example: 12,
                                           description: 'Length of program (in weeks)'
                property :facility_code, type: :string, example: '1X12345',
                                         description: 'Program institution facility code'
                property :institution_name, type: :string, example: 'CODE PLACE',
                                            description: 'Program institution name'
                property :city, type: %i[null string], example: 'ANYTOWN',
                                description: 'Program institution physical city location'
                property :state, type: %i[null string], example: 'WA',
                                 description: 'Program institution physical state location'
                property :country, type: %i[null string], example: 'USA',
                                   description: 'Program institution physical country location'
                property :preferred_provider, type: %i[null boolean], example: false,
                                              description: 'Program institution preferred provider indicator;
<<<<<<< HEAD
                                              a provider that takes on the costs of the veterans education if
                                               the requirements are not met'
                property :tuition_amount, type: %i[null integer], example: 1000,
                                          description: 'Program tuition amount'
                property :va_bah, type: %i[null number], example: 220,
=======
                                              a provider that takes on the costs of the veterans
                                              education if the requirements are not met'
                property :tuition_amount, type: %i[null integer], example: 1000,
                                          description: 'Program tuition amount'
                property :va_bah, type: %i[null integer], example: 220,
>>>>>>> 968f85cf52233cff7241b204a69588bc17794d43
                                  description: 'VA Basic Allowance for Housing'
                property :dod_bah, type: %i[null integer], example: 200,
                                   description: 'DOD Basic Allowance for Housing'
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
