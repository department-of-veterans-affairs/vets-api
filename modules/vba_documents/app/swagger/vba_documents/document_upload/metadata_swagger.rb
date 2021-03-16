# frozen_string_literal: true

module VBADocuments
  module DocumentUpload
    class MetadataSwagger
      include Swagger::Blocks

      swagger_component do
        schema :DocumentUploadMetadata do
          key :type, :object
          key :description, 'Identifying properties about the document payload being submitted'
          key :required, %i[veteranFirstName veteranLastName fileNumber zipCode source]

          property :veteranFirstName do
            key :type, :string
            key :description, 'Veteran first name'
            key :example, 'Jane'
          end

          property :veteranLastName do
            key :type, :string
            key :description, 'Veteran last name'
            key :example, 'Doe'
          end

          property :fileNumber do
            key :description, 'VA file number or SSN, 8 or 9 numeric characters, no hyphens, spaces, or punctuation'
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
            key :enum, %i[CMP PMC INS EDU VRE BVA FID OTH]
            key :description,
                <<~DESCRIPTION
                  Optional parameter (can be missing or empty).  The values are:<br>
                  CMP - Compensation requests such as those related to disability, unemployment, and pandemic claims<br>
                  PMC - Pension requests including survivor’s pension<br>
                  INS - Insurance such as life insurance, disability insurance, and other health insurance<br>
                  EDU - Education benefits, programs, and affiliations<br>
                  VRE – Veteran Readiness & Employment such as employment questionnaires, employment discrimination, employment verification<br>
                  BVA – Board of Veteran Appeals<br>
                  FID - Fiduciary / financial appointee, including family member benefits<br><br>
                  Future values (These values, if used, will be treated as CMP.):<br>
                  OTH – Other (this value if used, will be treated as CMP)<br>
                DESCRIPTION
          end
        end
      end
    end
  end
end
