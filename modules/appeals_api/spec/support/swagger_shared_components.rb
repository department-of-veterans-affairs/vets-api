# frozen_string_literal: true

# This class exists due to a limitation of the curl generation logic located in the "developer-portal" project.
# That curl generation logic cannot handle Swagger's "$ref" syntax.
# The "$ref" syntax allows you to define common code in a single location within Swagger & then reference where needed.
# This class helps bridge the gap between avoiding duplicated code and keeping the curl generation logic happy.
#
# Example
#  If you use "rswag" to define your API operations and you use a "$ref" in a definition.
#  The generated Swagger output will have an entry like this ::
#    "$ref": "#/components/parameters/veteranSSNHeader"
#  The logic in "developer-portal" can't work with that.
#  So instead, you can do this in your Swagger definition ::
#    'parameter SwaggerSharedComponents.header_params[:veteran_ssn_header]''
#  Then, in the generated Swagger output, you will have an entry like this that "developer-portal" can work with.
#  "parameters": [
#   {
#     "in": "header",
#     "name": "X-VA-SSN",
#     "required": false,
#     "description": "Veteran SSN if consumer is representative",
#     "schema": {
#       "type": "string"
#     }
#   }
# ]

class AppealsApi::SwaggerSharedComponents
  # rubocop:disable Metrics/MethodLength, Layout/LineLength
  def self.header_params
    {
      veteran_ssn_header: {
        in: :header,
        name: 'X-VA-SSN',
        required: true,
        description: 'Veteran\'s SSN',
        example: '706547821',
        schema: { '$ref' => '#/components/schemas/X-VA-SSN' }
      },
      veteran_icn_header: {
        in: :header,
        name: 'X-VA-ICN',
        required: false,
        description: 'Veteran\'s ICN',
        example: '1013062086V794840',
        schema: { '$ref' => '#/components/schemas/X-VA-ICN' }
      },
      veteran_first_name_header: {
        in: :header,
        name: 'X-VA-First-Name',
        required: true,
        description: 'Veteran\'s first name',
        example: 'Cara',
        schema: { '$ref' => '#/components/schemas/X-VA-First-Name' }
      },
      veteran_middle_initial_header: {
        in: :header,
        name: 'X-VA-Middle-Initial',
        required: false,
        description: 'Veteran\'s middle initial',
        schema: { '$ref' => '#/components/schemas/X-VA-Middle-Initial' }
      },
      veteran_last_name_header: {
        in: :header,
        name: 'X-VA-Last-Name',
        required: true,
        description: 'Veteran\'s last name',
        example: 'Bartlett',
        schema: { '$ref' => '#/components/schemas/X-VA-Last-Name' }
      },
      veteran_birth_date_header: {
        in: :header,
        name: 'X-VA-Birth-Date',
        required: true,
        description: 'Veteran\'s birth date',
        example: '1975-02-14',
        schema: { '$ref' => '#/components/schemas/X-VA-Birth-Date' }
      },
      veteran_file_number_header: {
        in: :header,
        name: 'X-VA-File-Number',
        required: false,
        description: 'Veteran\'s file number',
        schema: { '$ref' => '#/components/schemas/X-VA-File-Number' }
      },
      veteran_insurance_policy_number_header: {
        in: :header,
        name: 'X-VA-Insurance-Policy-Number',
        required: false,
        description: 'Veteran\'s insurance policy number',
        schema: { '$ref' => '#/components/schemas/X-VA-Insurance-Policy-Number' }
      },
      claimant_ssn_header: {
        in: :header,
        name: 'X-VA-NonVeteranClaimant-SSN',
        required: false,
        description: 'Non-Veteran claimant\'s SSN',
        schema: { '$ref' => '#/components/schemas/X-VA-NonVeteranClaimant-SSN' }
      },
      claimant_first_name_header: {
        in: :header,
        name: 'X-VA-NonVeteranClaimant-First-Name',
        required: false,
        description: 'Non-Veteran claimant\'s first name',
        schema: { '$ref' => '#/components/schemas/X-VA-NonVeteranClaimant-First-Name' }
      },
      claimant_middle_initial_header: {
        in: :header,
        name: 'X-VA-NonVeteranClaimant-Middle-Initial',
        required: false,
        description: 'Non-Veteran claimant\'s middle initial',
        schema: { '$ref' => '#/components/schemas/X-VA-NonVeteranClaimant-Middle-Initial' }
      },
      claimant_last_name_header: {
        in: :header,
        name: 'X-VA-NonVeteranClaimant-Last-Name',
        required: false,
        description: 'Non-Veteran claimant\'s last name',
        schema: { '$ref' => '#/components/schemas/X-VA-NonVeteranClaimant-Last-Name' }
      },
      claimant_birth_date_header: {
        in: :header,
        name: 'X-VA-NonVeteranClaimant-Birth-Date',
        required: false,
        description: 'Non-Veteran claimant\'s Birth Date',
        schema: { '$ref' => '#/components/schemas/X-VA-NonVeteranClaimant-Birth-Date' }
      },
      alternate_signer_first_name_header: {
        in: :header,
        name: 'X-Alternate-Signer-First-Name',
        required: false,
        description: 'Alternate signer\'s first name',
        schema: { '$ref' => '#/components/schemas/X-Alternate-Signer-First-Name' }
      },
      alternate_signer_middle_initial_header: {
        in: :header,
        name: 'X-Alternate-Signer-Middle-Initial',
        required: false,
        description: 'Alternate signer\'s middle initial',
        schema: { '$ref' => '#/components/schemas/X-Alternate-Signer-Middle-Initial' }
      },
      alternate_signer_last_name_header: {
        in: :header,
        name: 'X-Alternate-Signer-Last-Name',
        required: false,
        description: 'Alternate signer\'s last name',
        schema: { '$ref' => '#/components/schemas/X-Alternate-Signer-Last-Name' }
      },
      # Deprecated. Only used in decision_reviews endpoint docs
      consumer_username_header: {
        in: :header,
        type: :string,
        name: 'X-Consumer-Username',
        required: false,
        description: 'Consumer User Name (passed from Kong)'
      },
      # Deprecated. Only used in decision_reviews endpoint docs
      consumer_id_header: {
        in: :header,
        type: :string,
        name: 'X-Consumer-ID',
        required: false,
        description: 'Consumer GUID'
      },
      va_receipt_date: {
        in: :header,
        name: 'X-VA-Receipt-Date',
        required: true,
        description: '(yyyy-mm-dd) In order to determine contestability of issues, the receipt date of a hypothetical Decision Review must be specified. This date must be after 2019-02-19, the Appeals Modernization Act (AMA) Activation Date.',
        example: '2022-01-01',
        schema: { '$ref' => '#/components/schemas/X-VA-Receipt-Date' }
      }
    }
  end
  # rubocop:enable Metrics/MethodLength, Layout/LineLength
end
