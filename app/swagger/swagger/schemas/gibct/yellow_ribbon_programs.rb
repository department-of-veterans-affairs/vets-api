# frozen_string_literal: true

module Swagger
  module Schemas
    module Gibct
      class YellowRibbonPrograms
        include Swagger::Blocks

        swagger_schema :GibctYellowRibbonPrograms do
          key :required, %i[data meta links]

          property :data, type: :array, maxItems: 30, uniqueItems: true do
            items do
              key :type, :object
              key :required, %i[id type attributes]

              property :id, type: :string, example: '1226343'
              property :type, type: :string, enum: ['yellow_ribbon_programs'], example: 'yellow_ribbon_programs'
              property :attributes do
                key :required, %i[city
                                  contribution_amount
                                  correspondence
                                  country
                                  degree_level
                                  distance_learning
                                  division_professional_school
                                  facility_code
                                  institution_id
                                  insturl
                                  latitude
                                  longitude
                                  name_of_institution
                                  number_of_students
                                  online_only
                                  state
                                  street_address
                                  student_veteran
                                  student_veteran_link
                                  ungeocodable
                                  year_of_yr_participation
                                  zip]

                property :city, type: %i[null string], example: 'Abilene',
                                description: 'The city name where the Yellow Ribbon Program is located.'

                property :contribution_amount, type: %i[null string], example: '99999.0',
                                               description: 'The contribution amount in dollars.'

                property :correspondence, type: %i[null boolean], example: false,
                                          description: 'Indicates that this is only a correspondence institution.'

                property :country, type: %i[null string], example: 'USA',
                                   description: 'The country where the Yellow Ribbon Program is located.'

                property :distance_learning, type: %i[null boolean], example: false,
                                             description: 'Indicates that this institution offers off-campus options'

                property :degree_level, type: %i[null string], example: 'All',
                                        description: 'The degree levels available to the Yellow Ribbon Program.'

                property :division_professional_school, type: %i[null string], example: 'All',
                                                        description: 'The majors/minors of the Yellow Ribbon Program.'

                property :facility_code, type: %i[null string], example: '31000143',
                                         description: 'The faciliy code of the Yellow Ribbon Program.'

                property :institution_id, type: %i[null integer], example: 20_405_111,
                                          description: 'The institution ID the Yellow Ribbon Program belongs to.'

                property :insturl, type: %i[null string], example: 'www.acu.edu',
                                   description: 'The URL for the Yellow Ribbon Program\'s institution.'

                property :latitude, type: %i[null number], format: :double, example: 32.0713829183673,
                                    description: 'Geographic coordinate'

                property :longitude, type: %i[null number], format: :double, example: -84.2393880204082,
                                     description: 'Geographic coordinate'

                property :name_of_institution, type: %i[null string], example: 'ABILENE CHRISTIAN UNIVERSITY',
                                               description: 'The name of the school.'

                property :number_of_students, type: %i[null integer], example: 99_999,
                                              description: 'The number of students that can receive the benefit.'

                property :online_only, type: %i[null boolean], example: false,
                                       description: 'Indicates that this institution only offers online courses.'

                property :state, type: %i[null string], example: 'TX',
                                 description: 'The provincial state where the Yellow Ribbon Program is located.'

                property :street_address, type: %i[null string], example: '1600 Campus Court',
                                          description: 'The street address where the Yellow Ribbon Program is located.'

                property :student_veteran, type: %i[null boolean], example: false,
                                           description: 'Indicates that there is a student veterans group on campus.'

                property :student_veteran_link, type: %i[null string], example: 'https://www.example.com',
                                                description: 'Link to the student veterans group.'

                property :ungeocodable, type: %i[null boolean], example: false,
                                        description: 'Indicates a failure to resolve geographic coordinates.'

                property :year_of_yr_participation, type: %i[null string], example: '"2018/2019"',
                                                    description: 'The school year that this Yellow Ribbon' \
                                                                 'Program data is for.'

                property :zip, type: %i[null string], example: '"31709"',
                               description: 'Postal code'
              end
            end
          end

          property :meta, '$ref': :GibctYellowRibbonProgramsMeta
          property :links, '$ref': :GibctYellowRibbonProgramsLinks
        end

        swagger_schema :GibctYellowRibbonProgramsMeta do
          key :type, :object
          key :required, %i[version count]

          property :version, '$ref': :GibctVersion
          property :count, type: :integer, example: 790
        end

        swagger_schema :GibctYellowRibbonProgramsLinks do
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
