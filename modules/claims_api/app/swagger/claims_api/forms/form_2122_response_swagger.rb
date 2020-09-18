# frozen_string_literal: true

module ClaimsApi
  module Forms
    class Form2122ResponseSwagger
      include Swagger::Blocks

      EXAMPLE_PATH = ClaimsApi::Engine.root.join('app', 'swagger', 'claims_api', 'forms', 'form_2122_example.json')

      swagger_component do
        schema :Address do
          property :numberAndStreet do
            key :type, :string
            key :description, 'Street address with number and name'
          end

          property :city do
            key :type, :string
            key :example, 'Portland'
            key :description, 'City for the address'
          end

          property :state do
            key :type, :string
            key :example, 'OR'
            key :description, 'State for the address'
          end

          property :country do
            key :type, :string
            key :example, 'USA'
            key :description, 'Country of the address'
          end

          property :zipFirstFive do
            key :type, :string
            key :example, '12345'
            key :description, 'Zipcode (First 5 digits) of the address'
          end

          property :zipLastFour do
            key :type, :string
            key :example, '6789'
            key :description, 'Zipcode (Last 4 digits) of the address'
          end
        end

        schema :Phone do
          property :areaCode do
            key :type, :string
            key :example, '555'
            key :description, 'Area code of the phone number'
          end

          property :phoneNumber do
            key :type, :string
            key :example, '555-5555'
            key :description, 'phone number'
          end
        end

        schema :Veteran do
          property :address do
            key :type, :object
            key :'$ref', :Address
          end

          property :phone do
            key :type, :object
            key :'$ref', :Phone
          end

          property :email do
            key :type, :string
            key :description, 'Email address of the veteran'
            key :example, 'veteran@example.com'
          end

          property :serviceBranch do
            key :type, :string
            key :description, 'Service Branch for the veteran'
            key :example, 'ARMY'
            key :enum, [
              'AIR FORCE',
              'ARMY',
              'COAST GUARD',
              'MARINE CORPS',
              'NAVY',
              'OTHER'
            ]
          end
        end

        schema :Claimant do
          property :firstName do
            key :type, :string
            key :description, 'First name of Claimant'
            key :example, 'John'
          end

          property :middleInitial do
            key :type, :string
            key :description, 'Middle initial of Claimant'
            key :example, 'M'
          end

          property :lastName do
            key :type, :string
            key :description, 'Last name of Claimant'
            key :example, 'Dow'
          end

          property :email do
            key :type, :string
            key :description, 'Email address of the claimant'
            key :example, 'claimant@example.com'
          end

          property :address do
            key :type, :object
            key :'$ref', :Address
          end

          property :phone do
            key :type, :object
            key :'$ref', :Phone
          end

          property :relationship do
            key :type, :string
            key :description, 'Relationship of claimant to the veteran'
            key :example, 'Spouse'
          end
        end

        schema :Form2122Input do
          key :required, %i[type attributes]
          key :description, '2122 Power of Attorney Form submission'
          property :data do
            key :type, :object
            key :example, JSON.parse(File.read(EXAMPLE_PATH))
            property :type do
              key :type, :string
              key :example, 'form/21-22'
              key :description, 'Required by JSON API standard'
            end

            property :attributes do
              key :type, :object
              key :description, 'Required by JSON API standard'
              key :required, %i[serviceOrganization poaCode]

              property :serviceOrganization do
                key :type, :object
                key :description, 'Details of the Service Organization representing the veteran'
                key :required, %w[
                  poaCode
                ]

                property :poaCode do
                  key :type, :string
                  key :description, 'The POA code of the organization'
                  key :example, 'A1Q'
                end

                property :firstName do
                  key :type, :string
                  key :description, 'First Name of the representative'
                  key :example, 'John'
                end

                property :lastName do
                  key :type, :string
                  key :description, 'Last Name of the representative'
                  key :example, 'Doe'
                end

                property :organizationName do
                  key :type, :string
                  key :description, 'Name of the service organization'
                  key :example, 'I help vets LLC'
                end

                property :address do
                  key :type, :object
                  key :'$ref', :Address
                end

                property :jobTitle do
                  key :type, :string
                  key :description, 'Job title of the representative'
                  key :example, 'Veteran Service representative'
                end

                property :email do
                  key :type, :string
                  key :description, 'Email address of the service organization or representative'
                  key :example, 'veteran_representative@example.com'
                end

                property :appointmentDate do
                  key :type, :string
                  key :format, 'date'
                  key :example, '2018-08-28'
                  key :description, 'Date of appointment with Veteran'
                end
              end

              property :veteran do
                key :type, :object
                key :'$ref', :Veteran
              end

              property :claimant do
                key :type, :object
                key :'$ref', :Claimant
              end

              property :signatureFiles do
                key :type, :object
                property :veteran do
                  key :type, :string
                  key :description, 'Base64 encoded png image of the veterans signature'
                end
                property :representative do
                  key :type, :string
                  key :description, 'Base64 encoded png image of the representative signature'
                end
              end

              property :recordConsent do
                key :type, :boolean
                key :description, 'AUTHORIZATION FOR REPRESENTATIVE\'S ACCESS TO RECORDS PROTECTED BY SECTION 7332, TITLE 38, U.S.C.'
              end

              property :consentAddressChange do
                key :type, :boolean
                key :description, 'AUTHORIZATION FOR REPRESENTATIVE TO ACT ON CLAIMANT\'S BEHALF TO CHANGE CLAIMANT\'S ADDRESS'
              end

              property :consentLimit do
                key :type, :string
                key :description, 'Consent in Item 19 for the disclosure of records relating to treatment for drug abuse, alcoholism or alcohol abuse, infection
with the human immunodeficiency virus (HIV), or sickle cell anemia is limited as follows'
              end
            end
          end
        end

        schema :Form2122Output do
          key :required, %i[type attributes]
          key :description, '2122 Power of Attorney Form response'

          property :id do
            key :type, :string
            key :example, '6e47701b-802b-4520-8a41-9af2117a20bd'
            key :description, 'Power of Attorney Submission UUID'
          end

          property :type do
            key :type, :string
            key :example, 'evss_power_of_attorney'
            key :description, 'Required by JSON API standard'
          end

          property :attributes do
            key :type, :object
            key :description, 'Required by JSON API standard'

            property :relationship_type do
              key :type, :string
              key :example, ''
              key :description, 'Type of relationships'
            end

            property :date_request_accepted do
              key :type, :string
              key :format, 'date'
              key :example, '2014-07-28'
              key :description, 'Date request was first accepted'
            end

            property :status do
              key :type, :string
              key :example, 'submitted'
              key :description, 'Says if the power of attorney is pending, updated or errored'
              key :enum, %w[
                pending
                updated
                errored
              ]
            end

            property :representative do
              key :type, :object
              key :description, 'Information about VSO, Attorney or Claims Agents'

              property :poa_code do
                key :type, :string
                key :example, 'A01'
                key :description, 'Power of Attorney Code submitted for Veteran'
              end

              property :poa_first_name do
                key :type, :string
                key :example, 'John'
                key :description, 'Power of Attorney representative first name submitted for Veteran'
              end

              property :poa_last_name do
                key :type, :string
                key :example, 'Doe'
                key :description, 'Power of Attorney representative last name submitted for Veteran'
              end

              property :participant_id do
                key :type, :string
                key :example, '987654'
                key :description, 'Participant ID for veteran representative'
              end
            end

            property :veteran do
              key :type, :object
              key :description, 'Information about Veteran'

              property :participant_id do
                key :type, :string
                key :example, '14567'
                key :description, 'Participant ID for veteran'
              end
            end

            property :previous_poa do
              key :type, :string
              key :example, 'B02'
              key :description, 'Current or Previous Power of Attorney Code submitted for Veteran'
            end
          end
        end
      end
    end
  end
end
