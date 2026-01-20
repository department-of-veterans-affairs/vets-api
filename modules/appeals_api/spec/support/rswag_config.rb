# frozen_string_literal: true

require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'appeals_api/form_schemas'

# Allow use of DocHelpers outside of 'it' context
RSpec.configure { |_config| include DocHelpers }

# rubocop:disable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
class AppealsApi::RswagConfig
  def self.decision_reviews_description_file_name
    Flipper.enabled?(:decision_review_evidence_final_status_field) ? "description_with_final_status#{DocHelpers.doc_suffix}.md" : "api_description#{DocHelpers.doc_suffix}.md"
  end

  def rswag_doc_config(base_path_template:, description_file_path:, name:, tags:, version:)
    {
      # FIXME: The Lighthouse docs UI code does not yet support openapi versions above 3.0.z
      # This version should be updated to 3.1.0+ once that changes.
      openapi: '3.0.0',
      info: {
        title: DOC_TITLES[name.to_sym],
        version:,
        contact: { name: 'developer.va.gov' },
        description: File.read(description_file_path)
      },
      tags:,
      paths: {},
      components: {
        securitySchemes: name == 'decision_reviews' ? decision_reviews_security_schemes : oauth_security_schemes(name),
        schemas: schemas(api_name: name, version:)
      },
      servers: [
        {
          url: "https://sandbox-api.va.gov#{base_path_template}",
          description: 'VA.gov API sandbox environment',
          variables: { version: { default: version } }
        },
        {
          url: "https://api.va.gov#{base_path_template}",
          description: 'VA.gov API production environment',
          variables: { version: { default: version } }
        }
      ]
    }
  end

  def config
    {
      "modules/appeals_api/app/swagger/appealable_issues/v0/swagger#{DocHelpers.doc_suffix}.json" => rswag_doc_config(
        version: 'v0',
        description_file_path: AppealsApi::Engine.root.join("app/swagger/appealable_issues/v0/api_description#{DocHelpers.doc_suffix}.md"),
        base_path_template: '/services/appeals/appealable-issues/{version}',
        name: 'appealable_issues',
        tags: api_tags(:appealable_issues)
      ),
      "modules/appeals_api/app/swagger/appeals_status/v1/swagger#{DocHelpers.doc_suffix}.json" => rswag_doc_config(
        version: 'v1',
        description_file_path: AppealsApi::Engine.root.join("app/swagger/appeals_status/v1/api_description#{DocHelpers.doc_suffix}.md"),
        base_path_template: '/services/appeals/appeals-status/{version}',
        name: 'appeals_status',
        tags: api_tags(:appeals_status)
      ),
      "modules/appeals_api/app/swagger/decision_reviews/v2/swagger#{DocHelpers.doc_suffix}.json" => rswag_doc_config(
        version: 'v2',
        description_file_path: AppealsApi::Engine.root.join("app/swagger/decision_reviews/v2/#{self.class.decision_reviews_description_file_name}"),
        base_path_template: '/services/appeals/{version}/decision_reviews',
        name: 'decision_reviews',
        tags: api_tags(*%i[higher_level_reviews notice_of_disagreements supplemental_claims contestable_issues legacy_appeals])
      ),
      "modules/appeals_api/app/swagger/higher_level_reviews/v0/swagger#{DocHelpers.doc_suffix}.json" => rswag_doc_config(
        version: 'v0',
        description_file_path: AppealsApi::Engine.root.join("app/swagger/higher_level_reviews/v0/api_description#{DocHelpers.doc_suffix}.md"),
        base_path_template: '/services/appeals/higher-level-reviews/{version}',
        name: 'higher_level_reviews',
        tags: api_tags(:higher_level_reviews)
      ),
      "modules/appeals_api/app/swagger/legacy_appeals/v0/swagger#{DocHelpers.doc_suffix}.json" => rswag_doc_config(
        version: 'v0',
        description_file_path: AppealsApi::Engine.root.join("app/swagger/legacy_appeals/v0/api_description#{DocHelpers.doc_suffix}.md"),
        base_path_template: '/services/appeals/legacy-appeals/{version}',
        name: 'legacy_appeals',
        tags: api_tags(:legacy_appeals)
      ),
      "modules/appeals_api/app/swagger/notice_of_disagreements/v0/swagger#{DocHelpers.doc_suffix}.json" => rswag_doc_config(
        version: 'v0',
        description_file_path: AppealsApi::Engine.root.join("app/swagger/notice_of_disagreements/v0/api_description#{DocHelpers.doc_suffix}.md"),
        base_path_template: '/services/appeals/notice-of-disagreements/{version}',
        name: 'notice_of_disagreements',
        tags: api_tags(:notice_of_disagreements)
      ),
      "modules/appeals_api/app/swagger/supplemental_claims/v0/swagger#{DocHelpers.doc_suffix}.json" => rswag_doc_config(
        version: 'v0',
        description_file_path: AppealsApi::Engine.root.join("app/swagger/supplemental_claims/v0/api_description#{DocHelpers.doc_suffix}.md"),
        base_path_template: '/services/appeals/supplemental-claims/{version}',
        name: 'supplemental_claims',
        tags: api_tags(:supplemental_claims)
      )
    }
  end

  private

  DOC_TITLES = {
    appealable_issues: 'Appealable Issues',
    appeals_status: 'Appeals Status',
    contestable_issues: 'Contestable Issues',
    decision_reviews: 'Decision Reviews',
    higher_level_reviews: 'Higher-Level Reviews',
    legacy_appeals: 'Legacy Appeals',
    notice_of_disagreements: 'Notice of Disagreements',
    supplemental_claims: 'Supplemental Claims'
  }.freeze

  DEFAULT_READ_SCOPE = { 'appeals.read': 'Appeals info' }.freeze
  DEFAULT_WRITE_SCOPE = { 'appeals.write': 'Ability to submit appeals' }.freeze

  OAUTH_SCOPES = {
    appeals_status: {
      'AppealsStatus.read': 'Status of appeals and decision reviews'
    },
    appealable_issues: {
      'AppealableIssues.read': 'Appealable issues info'
    },
    higher_level_reviews: {
      'HigherLevelReviews.read': 'Higher-Level Reviews info',
      'HigherLevelReviews.write': 'Ability to submit Higher-Level Reviews'
    },
    legacy_appeals: {
      'LegacyAppeals.read': 'Legacy appeals info'
    },
    notice_of_disagreements: {
      'NoticeOfDisagreements.read': 'Board Appeals info',
      'NoticeOfDisagreements.write': 'Ability to submit Board Appeals'
    },
    supplemental_claims: {
      'SupplementalClaims.read': 'Supplemental Claims info',
      'SupplementalClaims.write': 'Ability to submit Supplemental Claims'
    }
  }.freeze

  def api_tags(*api_names) = api_names.map { |api_name| { name: DOC_TITLES[api_name.to_sym], description: '' } }

  def decision_reviews_security_schemes
    {
      apikey: {
        type: :apiKey,
        name: :apikey,
        in: :header
      }
    }
  end

  def scopes_for_user_type(scopes, user_type) = scopes.transform_keys { |k| "#{user_type}/#{k}" }

  def oauth_security_schemes(api_name)
    api_specific_scopes = OAUTH_SCOPES[api_name.to_sym]
    scopes = api_specific_scopes.merge(DEFAULT_READ_SCOPE)
    scopes.merge!(DEFAULT_WRITE_SCOPE) if api_specific_scopes.keys.any? { |name| name.end_with?('.write') }

    veteran_scopes = scopes_for_user_type(scopes, 'veteran')
    representative_scopes = scopes_for_user_type(scopes, 'representative')
    system_scopes = scopes_for_user_type(scopes, 'system')

    authorization_code_scopes = veteran_scopes.merge(representative_scopes)
    client_credentials_scopes = system_scopes

    description = "The authentication model for the #{DOC_TITLES[api_name.to_sym]} API uses OAuth 2.0/OpenID Connect. " \
                  'The following authorization models are supported: ' \
                  "[Authorization code flow](https://#{DocHelpers.doc_url_prefix}developer.va.gov/explore/api/#{api_name.dasherize}/authorization-code) " \
                  "and [Client Credentials Grant (CCG)](https://#{DocHelpers.doc_url_prefix}developer.va.gov/explore/api/#{api_name.dasherize}/client-credentials)."

    {
      bearer_token: {
        type: :http,
        scheme: :bearer,
        bearerFormat: :JWT
      },
      productionOauth: {
        type: :oauth2,
        description:,
        flows: {
          authorizationCode: {
            authorizationUrl: 'https://api.va.gov/oauth2/appeals/v1/authorization',
            tokenUrl: 'https://api.va.gov/oauth2/appeals/v1/token',
            scopes: authorization_code_scopes
          },
          clientCredentials: {
            tokenUrl: "To get production access, you must either work for VA or have specific VA agreements in place. If you have questions, [contact us](https://#{DocHelpers.doc_url_prefix}developer.va.gov/support/contact-us).",
            scopes: client_credentials_scopes
          }
        }
      },
      sandboxOauth: {
        type: :oauth2,
        description:,
        flows: {
          authorizationCode: {
            authorizationUrl: 'https://sandbox-api.va.gov/oauth2/appeals/v1/authorization',
            tokenUrl: 'https://sandbox-api.va.gov/oauth2/appeals/v1/token',
            scopes: authorization_code_scopes
          },
          clientCredentials: {
            tokenUrl: 'https://deptva-eval.okta.com/oauth2/auskff5o6xsoQVngk2p7/v1/token',
            scopes: client_credentials_scopes
          }
        }
      }
    }
  end

  def merge_schemas(*schema_parts) = schema_parts.reduce(&:merge).sort_by { |k, _| k.to_s.downcase }.to_h

  def schemas(api_name:, version:)
    case api_name
    when 'higher_level_reviews'
      merge_schemas(
        hlr_create_schemas,
        hlr_response_schemas,
        generic_schemas.slice(*%i[errorModel uuid]),
        shared_schemas.slice(*%w[address fileNumber icn nonBlankString phone ssn timezone])
      )
    when 'notice_of_disagreements'
      merge_schemas(
        nod_create_schemas,
        nod_response_schemas,
        appealable_issues_response_schemas.slice(*%i[appealableIssue]),
        generic_schemas.slice(*%i[errorModel uuid]),
        shared_schemas.slice(*%w[address fileNumber icn nonBlankString phone ssn timezone])
      )
    when 'supplemental_claims'
      merge_schemas(
        sc_create_schemas,
        sc_response_schemas,
        appealable_issues_response_schemas.slice(*%i[appealableIssue]),
        generic_schemas.slice(*%i[errorModel documentUploadMetadata]),
        shared_schemas.slice(*%w[address fileNumber icn nonBlankString phone ssn timezone])
      )
    when 'appealable_issues'
      merge_schemas(
        appealable_issues_response_schemas,
        generic_schemas.slice(*%i[errorModel]),
        shared_schemas.slice(*%w[icn])
      )
    when 'legacy_appeals'
      merge_schemas(
        legacy_appeals_schema,
        generic_schemas.slice(*%i[errorModel]),
        shared_schemas.slice(*%w[icn nonBlankString])
      )
    when 'appeals_status'
      merge_schemas(
        appeals_status_response_schemas,
        generic_schemas.slice(*(version == 'v0' ? %i[errorModel X-VA-SSN X-VA-User] : %i[errorModel])),
        shared_schemas.slice(*(version == 'v0' ? nil : %w[icn]))
      )
    when 'decision_reviews'
      merge_schemas(
        decision_reviews_hlr_create_schemas,
        decision_reviews_hlr_response_schemas,
        decision_reviews_nod_create_schemas,
        decision_reviews_nod_response_schemas,
        decision_reviews_sc_create_schemas,
        decision_reviews_sc_response_schemas,
        decision_reviews_sc_alt_signer_schemas,
        contestable_issues_schema,
        legacy_appeals_schema,
        generic_schemas.except(*%i[X-VA-User])
      )
    else
      raise "Don't know how to build schemas for '#{api_name}'"
    end
  end

  def generic_schemas
    nbs_ref = '#/components/schemas/nonBlankString'

    {
      errorModel: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json'))),
      errorWithTitleAndDetail: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            title: {
              type: 'string'
            },
            detail: {
              type: 'string'
            }
          }
        }
      },
      'X-VA-SSN': {
        description: 'social security number',
        type: 'string',
        minLength: 9,
        maxLength: 9,
        pattern: '^[0-9]{9}$'
      },
      'X-VA-ICN': {
        description: "Veteran's Integration Control Number, a unique identifier established via the Master Person Index (MPI)",
        type: 'string',
        minLength: 17,
        maxLength: 17,
        pattern: '^[0-9]{10}V[0-9]{6}$'
      },
      'X-VA-First-Name': {
        allOf: [
          { description: 'first name' },
          { type: 'string' }
        ]
      },
      'X-VA-Middle-Initial': {
        allOf: [
          { description: 'middle initial' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Last-Name': {
        allOf: [
          { description: 'last name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Birth-Date': {
        description: "Veteran's birth date",
        type: 'string',
        format: 'date'
      },
      'X-VA-NonVeteranClaimant-SSN': {
        type: 'string',
        description: 'Non-Veteran claimants\'s SSN',
        pattern: '^[0-9]{9}$'
      },
      'X-VA-NonVeteranClaimant-First-Name': {
        allOf: [
          { description: 'first name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-NonVeteranClaimant-Middle-Initial': {
        allOf: [
          { description: 'middle initial' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-NonVeteranClaimant-Last-Name': {
        allOf: [
          { description: 'last name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-NonVeteranClaimant-Birth-Date': {
        description: "Non-veteran claimant's birth date",
        type: 'string',
        format: 'date'
      },
      'X-VA-File-Number': {
        allOf: [
          { description: 'VA file number (c-file / css)' },
          { maxLength: 9 },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Insurance-Policy-Number': {
        allOf: [
          { description: "Veteran's insurance policy number", maxLength: 18 },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-User': {
        description: 'VA username of the person making the request',
        type: 'string'
      },
      'X-Consumer-Username': {
        allOf: [
          { description: 'Consumer Username (passed from Kong)' },
          { '$ref': nbs_ref }
        ]
      },
      'X-Consumer-ID': {
        allOf: [
          { description: 'Consumer GUID' },
          { '$ref': nbs_ref }
        ]
      },
      uuid: {
        type: 'string',
        pattern: '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
      },
      timeStamp: {
        type: 'string',
        pattern: '\\d{4}(-\\d{2}){2}T\\d{2}(:\\d{2}){2}\\.\\d{3}Z'
      },
      documentUploadMetadata: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'document_upload_metadata.json')))
    }
  end

  def appealable_issues_response_schemas
    {
      appealableIssues: {
        type: 'object',
        properties: {
          data: {
            type: 'array',
            items: {
              '$ref': '#/components/schemas/appealableIssue'
            }
          }
        }
      },
      appealableIssue: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'appealable_issue.json')))
    }
  end

  def contestable_issues_schema
    {
      contestableIssues: {
        type: 'object',
        properties: {
          data: {
            type: 'array',
            items: {
              '$ref': '#/components/schemas/contestableIssue'
            }
          }
        }
      },
      contestableIssue: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'contestable_issue.json'))),
      'X-VA-Receipt-Date': {
        description: '(yyyy-mm-dd) Date to limit the contestable issues',
        type: 'string',
        format: 'date'
      }
    }
  end

  def decision_reviews_hlr_create_schemas = parse_create_schema('decision_reviews', 'v2', '200996.json')

  def hlr_create_schemas
    hlr_schema = parse_create_schema('higher_level_reviews', 'v0', '200996.json', return_raw: true)
    {
      hlrCreate: { type: 'object' }.merge!(hlr_schema.slice(*%w[description properties required]))
    }
  end

  def decision_reviews_hlr_response_schemas
    schemas = hlr_response_schemas
    schemas = deep_replace_key(schemas, :createDate, :createdAt)
    schemas = deep_replace_key(schemas, :updateDate, :updatedAt)

    # ContestableIssuesShow is not part of the segmented HLR api, so we only add it for Decision Reviews
    schemas['hlrContestableIssuesShow'] = {
      type: 'object',
      properties: {
        data: {
          type: 'array',
          items: {
            type: 'object',
            description: 'A contestable issue (to contest this, you include it as a RequestIssue when creating a HigherLevelReview, SupplementalClaim, or Appeal)',
            properties: {
              type: {
                type: 'string',
                enum: [
                  'contestableIssue'
                ]
              },
              id: {
                type: 'string',
                nullable: true
              },
              attributes: {
                type: 'object',
                properties: {
                  ratingIssueReferenceId: {
                    type: 'string',
                    nullable: true,
                    description: 'RatingIssue ID',
                    example: '2385'
                  },
                  ratingIssueProfileDate: {
                    type: 'string',
                    nullable: true,
                    format: 'date',
                    description: '(yyyy-mm-dd) RatingIssue profile date',
                    example: '2006-05-31'
                  },
                  ratingIssueDiagnosticCode: {
                    type: 'string',
                    nullable: true,
                    description: 'RatingIssue diagnostic code',
                    example: '5005'
                  },
                  ratingDecisionReferenceId: {
                    type: 'string',
                    nullable: true,
                    description: 'The BGS ID for the contested rating decision. This may be populated while ratingIssueReferenceId is nil',
                    example: 'null'
                  },
                  decisionIssueId: {
                    type: 'integer',
                    nullable: true,
                    description: 'DecisionIssue ID',
                    example: nil
                  },
                  approxDecisionDate: {
                    type: 'string',
                    nullable: true,
                    format: 'date',
                    description: '(yyyy-mm-dd) Approximate decision date',
                    example: '2006-11-27'
                  },
                  description: {
                    type: 'string',
                    nullable: true,
                    description: 'Description',
                    example: 'Service connection for hypertension is granted with an evaluation of 10 percent effective July 24, 2005.'
                  },
                  rampClaimId: {
                    type: 'string',
                    nullable: true,
                    description: 'RampClaim ID',
                    example: 'null'
                  },
                  titleOfActiveReview: {
                    type: 'string',
                    nullable: true,
                    description: 'Title of DecisionReview that this issue is still active on',
                    example: 'null'
                  },
                  sourceReviewType: {
                    type: 'string',
                    nullable: true,
                    description: 'The type of DecisionReview (HigherLevelReview, SupplementalClaim, Appeal) the issue was last decided on (if any)',
                    example: 'null'
                  },
                  timely: {
                    type: 'boolean',
                    description: 'An issue is timely if the receipt date is within 372 dates of the decision date.',
                    example: false
                  },
                  activeReview: {
                    type: 'boolean',
                    description: 'Indicates whether this issue is already part of an active Decision Review that is being processed by VA. Submitting a Decision Review that includes a listed issue with an activeReview of true may result in VA rejecting the submission.',
                    example: false
                  },
                  latestIssuesInChain: {
                    type: 'array',
                    description: 'Shows the chain of decision and rating issues that preceded this issue. Only the most recent issue can be contested (the object itself that contains the latestIssuesInChain attribute).',
                    items: {
                      type: 'object',
                      properties: {
                        id: {
                          type: {
                            oneOf: [
                              { type: 'string', nullable: true },
                              { type: 'integer' }
                            ],
                            example: nil
                          }
                        },
                        approxDecisionDate: {
                          type: 'string',
                          nullable: true,
                          format: 'date',
                          example: '2006-11-27'
                        }
                      }
                    }
                  },
                  ratingIssueSubjectText: {
                    type: 'string',
                    nullable: true,
                    description: 'Short description of RatingIssue',
                    example: 'Hypertension'
                  },
                  ratingIssuePercentNumber: {
                    type: 'string',
                    nullable: true,
                    description: 'Numerical rating for RatingIssue',
                    example: '10'
                  },
                  isRating: {
                    type: 'boolean',
                    description: 'Whether or not this is a RatingIssue',
                    example: true
                  }
                }
              }
            }
          }
        }
      }
    }
    schemas
  end

  def hlr_response_schemas
    {
      hlrShow: {
        type: 'object',
        properties: {
          data: {
            properties: {
              id: {
                '$ref': '#/components/schemas/uuid'
              },
              type: {
                type: 'string',
                enum: ['higherLevelReview']
              },
              attributes: {
                properties: {
                  status: {
                    type: 'string',
                    example: AppealsApi::HlrStatus::V2_STATUSES.first,
                    enum: AppealsApi::HlrStatus::V2_STATUSES
                  },
                  updateDate: {
                    description: 'The last time the submission was updated',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  },
                  createDate: {
                    description: 'The time the submission was created',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  }
                }
              }
            },
            required: %w[id type attributes]
          }
        },
        required: ['data']
      }
    }
  end

  def decision_reviews_nod_create_schemas = parse_create_schema('decision_reviews', 'v2', '10182.json')

  def nod_create_schemas
    nod_schema = parse_create_schema('notice_of_disagreements', 'v0', '10182.json', return_raw: true)
    evidence_schema = parse_create_schema('notice_of_disagreements', 'v0', 'evidence_submission.json', return_raw: true)
    {
      nodCreate: { type: 'object' }.merge!(nod_schema.slice(*%w[description properties required])),
      nodEvidenceSubmissionCreate: { type: 'object' }.merge!(evidence_schema.slice(*%w[description properties required]))
    }
  end

  def decision_reviews_nod_response_schemas
    {
      nodCreateResponse: {
        description: 'Successful response of a 10182 form submission',
        type: 'object',
        properties: {
          data: {
            properties: {
              id: {
                type: 'string',
                description: 'Unique ID of created NOD',
                example: '97751cb6-d06d-4179-87f6-75e3fc9d875c'
              },
              type: {
                type: 'string',
                description: 'Name of record class',
                example: 'noticeOfDisagreement'
              },
              attributes: {
                type: 'object',
                properties: {
                  status: {
                    type: 'string',
                    description: 'Status of NOD',
                    example: AppealsApi::NodStatus::STATUSES.first,
                    enum: AppealsApi::NodStatus::STATUSES
                  },
                  createdAt: {
                    type: 'string',
                    description: 'Created timestamp of the NOD',
                    example: '2020-12-16T19:52:23.909Z'
                  },
                  updatedAt: {
                    type: 'string',
                    description: 'Updated timestamp of the NOD',
                    example: '2020-12-16T19:52:23.909Z'
                  }
                }
              },
              formData: {
                '$ref': '#/components/schemas/nodCreate'
              }
            }
          },
          included: {
            type: 'array',
            items: {
              '$ref': '#/components/schemas/contestableIssue'
            }
          }
        }
      },
      nodShowResponse: {
        type: 'object',
        properties: {
          data: {
            properties: {
              id: {
                '$ref': '#/components/schemas/uuid'
              },
              type: {
                type: 'string',
                enum: ['noticeOfDisagreement']
              },
              attributes: {
                properties: {
                  status: {
                    type: 'string',
                    example: AppealsApi::NodStatus::STATUSES.first,
                    enum: AppealsApi::NodStatus::STATUSES
                  },
                  updatedAt: {
                    description: 'The last time the submission was updated',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  },
                  createdAt: {
                    description: 'The time the submission was created',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  }
                }
              }
            },
            required: %w[id type attributes]
          }
        },
        required: ['data']
      },
      nodEvidenceSubmissionResponse: {
        type: 'object',
        properties: {
          data: {
            properties: {
              id: {
                description: 'The document upload identifier',
                type: 'string',
                format: 'uuid',
                example: '6d8433c1-cd55-4c24-affd-f592287a7572'
              },
              type: {
                description: 'JSON API type specification',
                type: 'string',
                example: 'evidenceSubmission'
              },
              attributes: {
                properties: {
                  status: {
                    type: 'string',
                    example: VBADocuments::UploadSubmission::ALL_STATUSES.first,
                    enum: VBADocuments::UploadSubmission::ALL_STATUSES
                  },
                  code: {
                    type: 'string',
                    nullable: true
                  },
                  detail: {
                    type: 'string',
                    nullable: true,
                    description: 'Human readable error detail. Only present if status = "error"'
                  },
                  appealType: {
                    description: 'Type of associated appeal',
                    type: 'string',
                    example: 'NoticeOfDisagreement'
                  },
                  appealId: {
                    description: 'GUID of associated appeal',
                    type: 'string',
                    format: 'uuid',
                    example: '2926ad2a-9372-48cf-8ec1-69e08e4799ef'
                  },
                  location: {
                    type: 'string',
                    nullable: true,
                    description: 'Location to which to PUT document Payload',
                    format: 'uri',
                    example: 'https://sandbox-api.va.gov/example_path_here/6d8433c1-cd55-4c24-affd-f592287a7572'
                  },
                  updatedAt: {
                    description: 'The last time the submission was updated',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  },
                  createdAt: {
                    description: 'The time the submission was created',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  },
                  finalStatus: {
                    description: 'Indicates whether the status of the submission is final. Submissions with a finalStatus of true will no longer update to a new status.',
                    type: 'boolean',
                    example: false
                  }
                }
              }
            },
            required: %w[id type attributes]
          }
        },
        required: ['data']
      }
    }
  end

  def nod_response_schemas
    schemas = decision_reviews_nod_response_schemas
    schemas = deep_replace_key(schemas, :createdAt, :createDate)
    schemas = deep_replace_key(schemas, :updatedAt, :updateDate)
    schemas.merge(
      {
        nodCreateResponse: {
          description: 'Successful response of a 10182 form submission',
          type: 'object',
          properties: {
            data: {
              properties: {
                id: {
                  type: 'string',
                  description: 'Unique ID of created NOD',
                  example: '97751cb6-d06d-4179-87f6-75e3fc9d875c'
                },
                type: {
                  type: 'string',
                  description: 'Name of record class',
                  example: 'noticeOfDisagreement'
                },
                attributes: {
                  type: 'object',
                  properties: {
                    status: {
                      type: 'string',
                      description: 'Status of NOD',
                      example: AppealsApi::NodStatus::STATUSES.first,
                      enum: AppealsApi::NodStatus::STATUSES
                    },
                    createDate: {
                      type: 'string',
                      description: 'Created timestamp of the NOD',
                      example: '2020-12-16T19:52:23.909Z'
                    },
                    updateDate: {
                      type: 'string',
                      description: 'Updated timestamp of the NOD',
                      example: '2020-12-16T19:52:23.909Z'
                    }
                  }
                },
                formData: {
                  '$ref': '#/components/schemas/nodCreate'
                }
              }
            },
            included: {
              type: 'array',
              items: {
                '$ref': '#/components/schemas/appealableIssue'
              }
            }
          }
        }
      }
    )
  end

  def decision_reviews_sc_create_schemas
    parse_create_schema('decision_reviews', 'v2', '200995.json')
  end

  def sc_create_schemas
    sc_schema = parse_create_schema('supplemental_claims', 'v0', '200995.json', return_raw: true)
    {
      scCreate: { type: 'object' }.merge!(sc_schema.slice(*%w[description properties required])),
      scEvidenceSubmissionCreate: parse_create_schema('supplemental_claims', 'v0', 'evidence_submission.json', return_raw: true)
    }
  end

  def decision_reviews_sc_response_schemas
    {
      scCreateResponse: {
        description: 'Successful response of a 200995 form submission',
        type: 'object',
        properties: {
          data: {
            properties: {
              id: {
                type: 'string',
                description: 'Unique ID of created SC',
                example: '97751cb6-d06d-4179-87f6-75e3fc9d875c'
              },
              type: {
                type: 'string',
                description: 'Name of record class',
                example: 'supplementalClaim'
              },
              attributes: {
                type: 'object',
                properties: {
                  status: {
                    type: 'string',
                    description: 'Status of SC',
                    example: AppealsApi::SupplementalClaim::STATUSES.first,
                    enum: AppealsApi::SupplementalClaim::STATUSES
                  },
                  createdAt: {
                    type: 'string',
                    description: 'Created timestamp of the SC',
                    example: '2020-12-16T19:52:23.909Z'
                  },
                  updatedAt: {
                    type: 'string',
                    description: 'Updated timestamp of the SC',
                    example: '2020-12-16T19:52:23.909Z'
                  }
                }
              },
              formData: { '$ref': '#/components/schemas/scCreate' }
            }
          },
          included: {
            type: 'array',
            items: {
              '$ref': '#/components/schemas/contestableIssue'
            }
          }
        }
      },
      scEvidenceSubmissionResponse: {
        type: 'object',
        properties: {
          data: {
            properties: {
              id: {
                description: 'The document upload identifier',
                type: 'string',
                format: 'uuid',
                example: '6d8433c1-cd55-4c24-affd-f592287a7572'
              },
              type: {
                description: 'JSON API type specification',
                type: 'string',
                example: 'evidenceSubmission'
              },
              attributes: {
                properties: {
                  status: {
                    type: 'string',
                    example: VBADocuments::UploadSubmission::ALL_STATUSES.first,
                    enum: VBADocuments::UploadSubmission::ALL_STATUSES
                  },
                  code: {
                    type: 'string',
                    nullable: true
                  },
                  detail: {
                    type: 'string',
                    nullable: true,
                    description: 'Human readable error detail. Only present if status = "error"'
                  },
                  appealType: {
                    description: 'Type of associated appeal',
                    type: 'string',
                    example: 'SupplementalClaim'
                  },
                  appealId: {
                    description: 'GUID of associated appeal',
                    type: 'string',
                    format: 'uuid',
                    example: '2926ad2a-9372-48cf-8ec1-69e08e4799ef'
                  },
                  location: {
                    type: 'string',
                    nullable: true,
                    description: 'Location to which to PUT document Payload',
                    format: 'uri',
                    example: 'https://sandbox-api.va.gov/example_path_here/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                  },
                  updatedAt: {
                    description: 'The last time the submission was updated',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  },
                  createdAt: {
                    description: 'The time the submission was created',
                    type: 'string',
                    format: 'date-time',
                    example: '2018-07-30T17:31:15.958Z'
                  },
                  finalStatus: {
                    description: 'Indicates whether the status of the submission is final. Submissions with a finalStatus of true will no longer update to a new status.',
                    type: 'boolean',
                    example: false
                  }
                }
              }
            },
            required: %w[id type attributes]
          }
        },
        required: ['data']
      }
    }
  end

  def sc_response_schemas
    schemas = decision_reviews_sc_response_schemas
    schemas = deep_replace_key(schemas, :createdAt, :createDate)
    schemas = deep_replace_key(schemas, :updatedAt, :updateDate)
    schemas.merge(
      {
        scCreateResponse: {
          description: 'Successful response of a 200995 form submission',
          type: 'object',
          properties: {
            data: {
              properties: {
                id: {
                  type: 'string',
                  description: 'Unique ID of created supplemental claim',
                  example: '97751cb6-d06d-4179-87f6-75e3fc9d875c'
                },
                type: {
                  type: 'string',
                  description: 'Type of record',
                  example: 'supplementalClaim'
                },
                attributes: {
                  type: 'object',
                  properties: {
                    status: {
                      type: 'string',
                      description: 'Status of created supplemental claim',
                      example: AppealsApi::SupplementalClaim::STATUSES.first,
                      enum: AppealsApi::SupplementalClaim::STATUSES
                    },
                    createDate: {
                      type: 'string',
                      description: 'Created timestamp of the supplemental claim',
                      example: '2020-12-16T19:52:23.909Z'
                    },
                    updateDate: {
                      type: 'string',
                      description: 'Updated timestamp of the supplemental claim',
                      example: '2020-12-16T19:52:23.909Z'
                    }
                  }
                },
                formData: { '$ref': '#/components/schemas/scCreate' }
              }
            },
            included: {
              type: 'array',
              items: {
                '$ref': '#/components/schemas/appealableIssue'
              }
            }
          }
        }
      }
    )
  end

  def decision_reviews_sc_alt_signer_schemas
    # Taken from 200995_headers.json
    {
      'X-Alternate-Signer-First-Name': {
        description: 'Alternate signer\'s first name',
        type: 'string',
        minLength: 1,
        maxLength: 30
      },
      'X-Alternate-Signer-Middle-Initial': {
        description: 'Alternate signer\'s middle initial',
        minLength: 1,
        maxLength: 1,
        '$ref': '#/components/schemas/nonBlankString'
      },
      'X-Alternate-Signer-Last-Name': {
        description: 'Alternate signer\'s last name',
        minLength: 1,
        maxLength: 40,
        '$ref': '#/components/schemas/nonBlankString'
      }
    }
  end

  def sc_alt_signer_schemas = decision_reviews_sc_alt_signer_schemas

  def legacy_appeals_schema
    {
      legacyAppeals: {
        type: 'object',
        properties: {
          data: {
            type: 'array',
            items: {
              '$ref': '#/components/schemas/legacyAppeal'
            }
          }
        }
      },
      legacyAppeal: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'legacy_appeal.json')))
    }
  end

  def appeals_status_response_schemas
    {
      appeals: {
        type: 'array',
        items: { '$ref': '#/components/schemas/appeal' }
      },
      appeal: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'appeal.json'))),
      eta: {
        type: 'object',
        description: 'Estimated decision dates for each docket.',
        properties: {
          directReview: {
            format: 'date',
            example: '2020-02-01'
          },
          evidenceSubmission: {
            format: 'date',
            example: '2024-06-01'
          },
          hearing: {
            format: 'date',
            example: '2024-06-01'
          }
        }
      },
      alert: {
        type: 'object',
        description: 'Notification of a request for more information or of a change in the appeal status that requires action.',
        properties: {
          type: {
            type: 'string',
            description: 'Enum of notifications for an appeal. Acronyms used include cavc (Court of Appeals for Veteran Claims), vso (Veteran Service Organization), and dro (Decision Review Officer).',
            example: 'form9_needed',
            enum: %w[form9_needed scheduled_hearing hearing_no_show held_for_evidence cavc_option ramp_eligible ramp_ineligible decision_soon blocked_by_vso scheduled_dro_hearing dro_hearing_no_show evidentiary_period ama_post_decision]
          },
          details: {
            description: 'Further information about the alert',
            type: 'object'
          }
        }
      },
      event: {
        type: 'object',
        description: 'Event during the appeals process',
        properties: {
          type: {
            type: 'string',
            example: 'soc',
            description: 'Enum of possible event types. Acronyms used include, nod (Notice of Disagreement), soc (Statement of Case), ssoc (Supplemental Statement of Case), ftr (Failed to Report), bva (Board of Veteran Appeals), cavc (Court of Appeals for Veteran Claims), and dro (Decision Review Officer).',
            enum: %w[claim_decision nod soc form9 ssoc certified hearing_held hearing_no_show bva_decision field_grant withdrawn ftr ramp death merged record_designation reconsideration vacated other_close cavc_decision ramp_notice transcript remand_return ama_nod docket_change distributed_to_vlj bva_decision_effectuation dta_decision sc_request sc_decision sc_other_close hlr_request hlr_decision hlr_dta_error hlr_other_close statutory_opt_in]
          },
          date: {
            type: 'string',
            format: 'date',
            description: 'Date the event occurred',
            example: '2016-05-30'
          },
          details: {
            description: 'Further information about the event',
            type: 'object'
          }
        }
      },
      issue: {
        type: 'object',
        description: 'Issues on appeal',
        properties: {
          active: {
            type: 'boolean',
            example: true,
            description: 'Whether the issue is presently under contention.'
          },
          description: {
            type: 'string',
            example: 'Service connection, tinnitus',
            description: 'Description of the Issue'
          },
          diagnosticCode: {
            nullable: true,
            type: 'string',
            example: '6260',
            description: 'The CFR (Code of Federal Regulations) diagnostic code for the issue, if applicable'
          },
          lastAction: {
            nullable: true,
            type: 'string',
            description: 'Most recent decision made on this issue',
            enum: %w[field_grant withdrawn allowed denied remand cavc_remand]
          },
          date: {
            anyOf: [
              nullable: true,
              type: 'string',
              format: 'date',
              description: 'The date of the most recent decision on the issue',
              example: '2016-05-30'
            ]
          }
        }
      },
      evidence: {
        type: 'object',
        description: 'Documentation and other evidence that has been submitted in support of the appeal',
        properties: {
          description: {
            type: 'string',
            example: 'Service treatment records',
            description: 'Short text describing what the evidence is'
          },
          date: {
            type: 'string',
            format: 'date',
            description: 'Date the evidence was added to the case',
            example: '2017-09-30'
          }
        }
      }
    }
  end

  # @return Hash<String,Hash> a map of shared schema names to shared schemas
  def shared_schemas
    # Keys are strings to override older, non-shared-schema definitions
    AppealsApi::FormSchemas::ALL_SHARED_SCHEMA_TYPES.index_with do |name|
      AppealsApi::FormSchemas.load_shared_schema(name, 'v0', strip_description: true)
    end
  end

  def parse_create_schema(api_name, api_version, schema_file, return_raw: false)
    file = File.read(AppealsApi::Engine.root.join('config', 'schemas', api_name, api_version, schema_file))
    file.gsub! '#/definitions/', '#/components/schemas/'
    schema = JSON.parse file

    schema.deep_transform_values! do |value|
      if value.respond_to?(:end_with?) && value.end_with?('.json')
        "#/components/schemas/#{value.gsub('.json', '')}"
      else
        value
      end
    end

    return_raw ? schema : schema['definitions']
  end
end
# rubocop:enable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
