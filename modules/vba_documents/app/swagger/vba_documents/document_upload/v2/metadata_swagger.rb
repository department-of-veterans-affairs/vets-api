# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    module V2
      class MetadataSwagger
        include Swagger::Blocks

        swagger_component do
          schema :DocumentUploadMetadata do
            key :type, :object
            key :description, 'Identifying properties about the document payload being submitted'
            key :required, %i[veteranFirstName veteranLastName fileNumber zipCode source]

            property :veteranFirstName do
              key :type, :string
              key :description, 'Veteran first name. Cannot be missing or empty or longer than 50 characters. Only upper/lower case letters, hyphens(-), spaces and forward-slash(/) allowed.'
              key :pattern, '^[a-zA-Z\-\/\s]{1,50}$'
              key :example, 'Jane'
            end

            property :veteranLastName do
              key :type, :string
              key :description, 'Veteran last name. Cannot be missing or empty or longer than 50 characters. Only upper/lower case letters, hyphens(-), spaces and forward-slash(/) allowed.'
              key :pattern, '^[a-zA-Z\-\/\s]{1,50}$'
              key :example, 'Doe-Smith'
            end

            property :fileNumber do
              key :description, 'The Veteran\'s file number is exactly 9 digits with no alpha characters, hyphens, spaces or punctuation. In most cases, this is the Veteran\'s SSN but may also be an 8 digit BIRL number. If no file number has been established or if it is unknown, the application should use the Veteran\'s SSN and the file number will be associated with the submission later in the process. Incorrect file numbers can cause delays.'
              key :pattern, '^\d{8,9}$'
              key :example, '999887777'
              key :type, :string
            end

            property :zipCode do
              key :type, :string
              key :example, '20571'
              key :description, "Veteran zip code. Either five digits (XXXXX) or five digits then four digits separated by a hyphen (XXXXX-XXXX). Use '00000' for Veterans with non-US addresses."
            end

            property :source do
              key :type, :string
              key :example, 'MyVSO'
              key :description, 'System, installation, or entity submitting the document'
            end

            property :docType do
              key :type, :string
              key :example, '21-22'
              key :description, 'VBA form number of the document'
            end

            property :businessLine do
              key :type, :string
              key :example, 'CMP'
              key :enum, %i[CMP PMC INS EDU VRE BVA FID NCA OTH]
              key :description,
                  <<~DESCRIPTION
                    Cannot be missing or empty.  The valid values are:<br><br>
                    CMP - Compensation requests such as those related to disability, unemployment, and pandemic claims<br><br>
                    PMC - Pension requests including survivor’s pension<br><br>
                    INS - Insurance such as life insurance, disability insurance, and other health insurance<br><br>
                    EDU - Education benefits, programs, and affiliations<br><br>
                    VRE - Veteran Readiness & Employment such as employment questionnaires, employment discrimination, employment verification<br><br>
                    BVA - Board of Veteran Appeals<br><br>
                    FID - Fiduciary / financial appointee, including family member benefits<br><br>
                    NCA - National Cemetery Administration<br><br>
                    OTH - Other (this value if used, will be treated as CMP)<br>
                  DESCRIPTION
            end
          end
        end
      end
    end
  end
end
