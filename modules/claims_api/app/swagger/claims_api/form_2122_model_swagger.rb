# frozen_string_literal: true

module ClaimsApi
    class Form0966ModelSwagger
      include Swagger::Blocks
  
      swagger_schema :Form2122Input do
        key :required, %i[type attributes]
        key :description, '2122 Power of Attorney Form submission'
  
        property :type do
          key :type, :string
          key :example, 'form/21-22'
          key :description, 'Required by JSON API standard'
        end
  
        property :attributes do
          key :type, :object
          key :description, 'Required by JSON API standard'
  
          property :poa_code do
            key :type, :string
            key :example, 'A01'
            key :description, 'Power of Attorney Code being submitted for Veteran'
          end
  
          property :poa_first_name do
            key :type, :string
            key :example, 'Bob'
            key :description, 'First Name of person in organization being associated with Power of Attorney'
          end

          property :poa_last_name do
            key :type, :string
            key :example, 'Jones'
            key :description, 'Last Name of person in organization being associated with Power of Attorney'
          end
        end
      end

      swagger_schema :Form2122Output do
        key :required, %i[type attributes]
        key :description, '2122 Power of Attorney Form response'
  
        property :id do
          key :type, :string
          key :example, 'A01'
          key :description, 'Power of Attorney ID Code'
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
            key :format, 'datetime'
            key :example, '2015-08-28T19:52:25.601+00:00'
            key :description, 'One year from initial intent to file Datetime'
          end

          property :date_filed do
            key :type, :string
            key :format, 'datetime'
            key :example, '2014-07-28T19:53:45.810+00:00'
            key :description, 'Datetime intent to file was first called'
          end
  
          property :expiration_date do
            key :type, :string
            key :format, 'datetime'
            key :example, '2015-08-28T19:52:25.601+00:00'
            key :description, 'One year from initial intent to file Datetime'
          end
  
          property :type do
            key :type, :string
            key :example, 'compensation'
            key :description, 'Type of claim being submitted'
            key :enum, %w[
              compensation
              burial
              pension
            ]
          end
  
          property :status do
            key :type, :string
            key :example, 'active'
            key :description, 'Says if the Intent to File is Active or Expired'
          end
        end
      end
    end
  end
  