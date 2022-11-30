# frozen_string_literal: true

require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
class AppealsApi::RswagConfig
  include DocHelpers

  def config
    {
      DocHelpers.output_json_path => {
        openapi: DocHelpers.openapi_version,
        info: {
          title: DocHelpers.api_title,
          version: DocHelpers.api_version,
          contact: { name: 'developer.va.gov' },
          termsOfService: 'https://developer.va.gov/terms-of-service',
          description: File.read(DocHelpers.api_description_file_path)
        },
        tags: DocHelpers.api_tags,
        paths: {},
        # basePath helps with rswag runs, but is not valid OAS v3. rswag.rake removes it from the output file.
        basePath: DocHelpers.api_base_path,
        components: {
          securitySchemes: security_schemes,
          schemas: schemas(DocHelpers.api_name)
        },
        servers: [
          {
            url: "https://sandbox-api.va.gov#{DocHelpers.api_base_path_template}",
            description: 'VA.gov API sandbox environment',
            variables: {
              version: {
                default: DocHelpers.api_version
              }
            }
          },
          {
            url: "https://api.va.gov#{DocHelpers.api_base_path_template}",
            description: 'VA.gov API production environment',
            variables: {
              version: {
                default: DocHelpers.api_version
              }
            }
          }
        ]
      }
    }
  end

  private

  def security_schemes
    schemes = {
      apikey: {
        type: :apiKey,
        name: :apikey,
        in: :header
      }
    }

    return schemes if DocHelpers.decision_reviews?

    schemes.merge(
      {
        bearer_token: {
          type: :http,
          scheme: :bearer,
          bearerFormat: :JWT
        },
        productionOauth: {
          type: :oauth2,
          description: 'This API uses OAuth 2 with the authorization code grant flow. [More info](https://developer.va.gov/explore/authorization?api=claims)',
          flows: {
            authorizationCode: {
              authorizationUrl: 'https://api.va.gov/oauth2/authorization',
              tokenUrl: 'https://api.va.gov/oauth2/token',
              scopes: {
                'claim.read': 'Retrieve claim data',
                'claim.write': 'Submit claim data'
              }
            }
          }
        },
        sandboxOauth: {
          type: :oauth2,
          description: 'This API uses OAuth 2 with the authorization code grant flow. [More info](https://developer.va.gov/explore/authorization?api=claims)',
          flows: {
            authorizationCode: {
              authorizationUrl: 'https://sandbox-api.va.gov/oauth2/authorization',
              tokenUrl: 'https://sandbox-api.va.gov/oauth2/token',
              scopes: {
                'claim.read': 'Retrieve claim data',
                'claim.write': 'Submit claim data'
              }
            }
          }
        }
      }
    )
  end

  def schemas(api_name = nil)
    a = []
    case api_name
    when 'higher_level_reviews'
      a << hlr_v2_create_schemas
      a << hlr_v2_response_schemas('#/components/schemas')
      a << generic_schemas('#/components/schemas').except(
        *%i[
          errorWithTitleAndDetail timeStamp X-Consumer-Username X-Consumer-ID
        ]
      )
      a << shared_schemas
    when 'notice_of_disagreements'
      a << nod_v2_create_schemas
      a << nod_v2_response_schemas('#/components/schemas')
      a << contestable_issues_schema('#/components/schemas').slice(*%i[contestableIssue])
      a << generic_schemas('#/components/schemas').except(
        *%i[
          errorWithTitleAndDetail timeStamp X-Consumer-ID X-Consumer-Username X-VA-Insurance-Policy-Number
          X-VA-NonVeteranClaimant-SSN X-VA-SSN
        ]
      )
      a << shared_schemas.slice(*%I[address phone timezone #{nbs_key}])
    when 'supplemental_claims'
      a << sc_create_schemas
      a << sc_response_schemas('#/components/schemas')
      a << sc_alternate_signer_schemas('#/components/schemas')
      a << contestable_issues_schema('#/components/schemas').slice(*%i[contestableIssue])
      a << generic_schemas('#/components/schemas').except(
        *%i[
          errorWithTitleAndDetail timeStamp uuid X-Consumer-ID X-Consumer-Username X-VA-NonVeteranClaimant-SSN
          X-VA-NonVeteranClaimant-Birth-Date
        ]
      )
      a << shared_schemas.slice(*%I[address phone timezone #{nbs_key}])
    when 'contestable_issues'
      a << contestable_issues_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas').slice(*%i[errorModel X-VA-SSN X-VA-File-Number])
      a << shared_schemas.slice(*%I[#{nbs_key}])
    when 'legacy_appeals'
      a << legacy_appeals_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas').slice(*%i[errorModel X-VA-SSN X-VA-File-Number])
      a << shared_schemas.slice(*%I[#{nbs_key}])
    when nil
      a << hlr_v2_create_schemas
      a << hlr_v2_response_schemas('#/components/schemas')
      a << nod_v2_create_schemas
      a << nod_v2_response_schemas('#/components/schemas')
      a << sc_create_schemas
      a << sc_response_schemas('#/components/schemas')
      a << contestable_issues_schema('#/components/schemas')
      a << legacy_appeals_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas')
    else
      raise "Don't know how to build schemas for '#{api_name}'"
    end

    a.reduce(&:merge).sort_by { |k, _| k.to_s.downcase }.to_h
  end

  def generic_schemas(ref_root)
    nbs_ref = "#{ref_root}/#{nbs_key}"

    schemas = {
      'errorModel': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json'))),
      'errorWithTitleAndDetail': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string'
            },
            'detail': {
              'type': 'string'
            }
          }
        }
      },
      'X-VA-SSN': {
        'description': 'social security number',
        'type': 'string',
        'minLength': 9,
        'maxLength': 9,
        'pattern': '^[0-9]{9}$'
      },
      'X-VA-First-Name': {
        'allOf': [
          { 'description': 'first name' },
          { 'type': 'string' }
        ]
      },
      'X-VA-Middle-Initial': {
        'allOf': [
          { 'description': 'middle initial' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Last-Name': {
        'allOf': [
          { 'description': 'last name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Birth-Date': {
        'description': "Veteran's birth date",
        'type': 'string',
        'format': 'date'
      },
      'X-VA-NonVeteranClaimant-SSN': {
        'type': 'string',
        'description': 'Non-Veteran claimants\'s SSN',
        'pattern': '^[0-9]{9}$'
      },
      'X-VA-NonVeteranClaimant-First-Name': {
        'allOf': [
          { 'description': 'first name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-NonVeteranClaimant-Middle-Initial': {
        'allOf': [
          { 'description': 'middle initial' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-NonVeteranClaimant-Last-Name': {
        'allOf': [
          { 'description': 'last name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-NonVeteranClaimant-Birth-Date': {
        'description': "Non-veteran claimant's birth date",
        'type': 'string',
        'format': 'date'
      },
      'X-VA-File-Number': {
        'allOf': [
          { 'description': 'VA file number (c-file / css)' },
          { 'maxLength': 9 },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Insurance-Policy-Number': {
        'allOf': [
          { "description": "Veteran's insurance policy number", "maxLength": 18 },
          { "$ref": nbs_ref }
        ]
      },
      'X-Consumer-Username': {
        'allOf': [
          { 'description': 'Consumer Username (passed from Kong)' },
          { '$ref': nbs_ref }
        ]
      },
      'X-Consumer-ID': {
        'allOf': [
          { 'description': 'Consumer GUID' },
          { '$ref': nbs_ref }
        ]
      },
      'uuid': {
        'type': 'string',
        'pattern': '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
      },
      'timeStamp': {
        'type': 'string',
        'pattern': '\\d{4}(-\\d{2}){2}T\\d{2}(:\\d{2}){2}\\.\\d{3}Z'
      }
    }

    return schemas if ENV['API_NAME'].in?(%w[higher_level_reviews])

    # Add in extra schemas for non-HLR api docs
    schemas['documentUploadMetadata'] = JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'document_upload_metadata.json')))
    schemas
  end

  def contestable_issues_schema(ref_root)
    {
      'contestableIssues': {
        'type': 'object',
        'properties': {
          'data': {
            'type': 'array',
            'items': {
              '$ref': "#{ref_root}/contestableIssue"
            }
          }
        }
      },
      'contestableIssue': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'contestable_issue.json'))),
      'X-VA-Receipt-Date': {
        "description": '(yyyy-mm-dd) Date to limit the contestable issues',
        "type": 'string',
        "format": 'date'
      }
    }
  end

  def hlr_v2_create_schemas
    if DocHelpers.wip_doc_enabled?(:segmented_apis)
      hlr_schema = parse_create_schema('v2', '200996_with_shared_refs.json', return_raw: true)
      {
        hlrCreate: { type: 'object' }.merge!(hlr_schema.slice(*%w[description properties required]))
      }
    else
      parse_create_schema 'v2', '200996.json'
    end
  end

  def hlr_v2_response_schemas(ref_root)
    schemas = {
      'hlrShow': {
        'type': 'object',
        'properties': {
          'data': {
            'properties': {
              'id': {
                '$ref': "#{ref_root}/uuid"
              },
              'type': {
                'type': 'string',
                'enum': ['higherLevelReview']
              },
              'attributes': {
                'properties': {
                  'status': {
                    'type': 'string',
                    'example': AppealsApi::HlrStatus::V2_STATUSES.first,
                    'enum': AppealsApi::HlrStatus::V2_STATUSES
                  },
                  'updatedAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  },
                  'createdAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  }
                }
              }
            },
            'required': %w[id type attributes]
          }
        },
        'required': ['data']
      }
    }

    # ContestableIssuesShow is not part of the segmented HLR api, so skip it when we're generating segmented docs
    return schemas if DocHelpers.wip_doc_enabled?(:segmented_apis, true)

    schemas['hlrContestableIssuesShow'] = {
      'type': 'object',
      'properties': {
        'data': {
          'type': 'array',
          'items': {
            'type': 'object',
            'description': 'A contestable issue (to contest this, you include it as a RequestIssue when creating a HigherLevelReview, SupplementalClaim, or Appeal)',
            'properties': {
              'type': {
                'type': 'string',
                'enum': [
                  'contestableIssue'
                ]
              },
              'id': {
                'type': 'string',
                'nullable': true
              },
              'attributes': {
                'type': 'object',
                'properties': {
                  'ratingIssueReferenceId': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'RatingIssue ID',
                    'example': '2385'
                  },
                  'ratingIssueProfileDate': {
                    'type': 'string',
                    'nullable': true,
                    'format': 'date',
                    'description': '(yyyy-mm-dd) RatingIssue profile date',
                    'example': '2006-05-31'
                  },
                  'ratingIssueDiagnosticCode': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'RatingIssue diagnostic code',
                    'example': '5005'
                  },
                  'ratingDecisionReferenceId': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'The BGS ID for the contested rating decision. This may be populated while ratingIssueReferenceId is nil',
                    'example': 'null'
                  },
                  'decisionIssueId': {
                    'type': 'integer',
                    'nullable': true,
                    'description': 'DecisionIssue ID',
                    'example': 'null'
                  },
                  'approxDecisionDate': {
                    'type': 'string',
                    'nullable': true,
                    'format': 'date',
                    'description': '(yyyy-mm-dd) Approximate decision date',
                    'example': '2006-11-27'
                  },
                  'description': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Description',
                    'example': 'Service connection for hypertension is granted with an evaluation of 10 percent effective July 24, 2005.'
                  },
                  'rampClaimId': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'RampClaim ID',
                    'example': 'null'
                  },
                  'titleOfActiveReview': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Title of DecisionReview that this issue is still active on',
                    'example': 'null'
                  },
                  'sourceReviewType': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'The type of DecisionReview (HigherLevelReview, SupplementalClaim, Appeal) the issue was last decided on (if any)',
                    'example': 'null'
                  },
                  'timely': {
                    'type': 'boolean',
                    'description': 'An issue is timely if the receipt date is within 372 dates of the decision date.',
                    'example': false
                  },
                  'latestIssuesInChain': {
                    'type': 'array',
                    'description': 'Shows the chain of decision and rating issues that preceded this issue. Only the most recent issue can be contested (the object itself that contains the latestIssuesInChain attribute).',
                    'items': {
                      'type': 'object',
                      'properties': {
                        'id': {
                          'type': {
                            "oneOf": [
                              { 'type': 'string', 'nullable': true },
                              { 'type': 'integer' }
                            ],
                            'example': nil
                          }
                        },
                        'approxDecisionDate': {
                          'type': 'string',
                          'nullable': true,
                          'format': 'date',
                          'example': '2006-11-27'
                        }
                      }
                    }
                  },
                  'ratingIssueSubjectText': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Short description of RatingIssue',
                    'example': 'Hypertension'
                  },
                  'ratingIssuePercentNumber': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Numerical rating for RatingIssue',
                    'example': '10'
                  },
                  'isRating': {
                    'type': 'boolean',
                    'description': 'Whether or not this is a RatingIssue',
                    'example': true
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

  def nod_v2_create_schemas
    if DocHelpers.wip_doc_enabled?(:segmented_apis)
      nod_schema = parse_create_schema('v2', '10182_with_shared_refs.json', return_raw: true)
      {
        nodCreate: { type: 'object' }.merge!(nod_schema.slice(*%w[description properties required]))
      }
    else
      parse_create_schema 'v2', '10182.json'
    end
  end

  def nod_v2_response_schemas(ref_root)
    {
      'nodCreateResponse': {
        'description': 'Successful response of a 10182 form submission',
        'type': 'object',
        'properties': {
          'data': {
            'properties': {
              'id': {
                'type': 'string',
                'description': 'Unique ID of created NOD',
                'example': '97751cb6-d06d-4179-87f6-75e3fc9d875c'
              },
              'type': {
                'type': 'string',
                'description': 'Name of record class',
                'example': 'noticeOfDisagreement'
              },
              'attributes': {
                'type': 'object',
                'properties': {
                  'status': {
                    'type': 'string',
                    'description': 'Status of NOD',
                    'example': AppealsApi::NodStatus::STATUSES.first,
                    'enum': AppealsApi::NodStatus::STATUSES
                  },
                  'createdAt': {
                    'type': 'string',
                    'description': 'Created timestamp of the NOD',
                    'example': '2020-12-16T19:52:23.909Z'
                  },
                  'updatedAt': {
                    'type': 'string',
                    'description': 'Updated timestamp of the NOD',
                    'example': '2020-12-16T19:52:23.909Z'
                  }
                }
              },
              'formData': {
                '$ref': "#{ref_root}/nodCreate"
              }
            }
          },
          'included': {
            'type': 'array',
            'items': {
              '$ref': "#{ref_root}/contestableIssue"
            }
          }
        }
      },
      'nodShowResponse': {
        'type': 'object',
        'properties': {
          'data': {
            'properties': {
              'id': {
                '$ref': "#{ref_root}/uuid"
              },
              'type': {
                'type': 'string',
                'enum': ['noticeOfDisagreement']
              },
              'attributes': {
                'properties': {
                  'status': {
                    'type': 'string',
                    'example': AppealsApi::NodStatus::STATUSES.first,
                    'enum': AppealsApi::NodStatus::STATUSES
                  },
                  'updatedAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  },
                  'createdAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  }
                }
              }
            },
            'required': %w[id type attributes]
          }
        },
        'required': ['data']
      },
      'nodEvidenceSubmissionResponse': {
        'type': 'object',
        'properties': {
          'data': {
            'properties': {
              'id': {
                'description': 'The document upload identifier',
                'type': 'string',
                'format': 'uuid',
                'example': '6d8433c1-cd55-4c24-affd-f592287a7572'
              },
              'type': {
                'description': 'JSON API type specification',
                'type': 'string',
                'example': 'evidenceSubmission'
              },
              'attributes': {
                'properties': {
                  'status': {
                    'type': 'string',
                    'example': VBADocuments::UploadSubmission::ALL_STATUSES.first,
                    'enum': VBADocuments::UploadSubmission::ALL_STATUSES
                  },
                  'code': {
                    'type': 'string',
                    'nullable': true
                  },
                  'detail': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Human readable error detail. Only present if status = "error"'
                  },
                  'appealType': {
                    'description': 'Type of associated appeal',
                    'type': 'string',
                    'example': 'NoticeOfDisagreement'
                  },
                  'appealId': {
                    'description': 'GUID of associated appeal',
                    'type': 'string',
                    'format': 'uuid',
                    'example': '2926ad2a-9372-48cf-8ec1-69e08e4799ef'
                  },
                  'location': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Location to which to PUT document Payload',
                    'format': 'uri',
                    'example': 'https://sandbox-api.va.gov/example_path_here/6d8433c1-cd55-4c24-affd-f592287a7572'
                  },
                  'updatedAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  },
                  'createdAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  }
                }
              }
            },
            'required': %w[id type attributes]
          }
        },
        'required': ['data']
      }
    }
  end

  def sc_create_schemas
    if DocHelpers.wip_doc_enabled?(:segmented_apis)
      sc_schema = parse_create_schema('v2', '200995_with_shared_refs.json', return_raw: true)
      {
        scCreate: { type: 'object' }.merge!(sc_schema.slice(*%w[description properties required]))
      }
    else
      parse_create_schema 'v2', '200995.json'
    end
  end

  def nbs_key
    DocHelpers.decision_reviews? ? 'nonBlankString' : 'non_blank_string'
  end

  def sc_response_schemas(ref_root)
    {
      'scCreateResponse': {
        'description': 'Successful response of a 200995 form submission',
        'type': 'object',
        'properties': {
          'data': {
            'properties': {
              'id': {
                'type': 'string',
                'description': 'Unique ID of created SC',
                'example': '97751cb6-d06d-4179-87f6-75e3fc9d875c'
              },
              'type': {
                'type': 'string',
                'description': 'Name of record class',
                'example': 'supplementalClaim'
              },
              'attributes': {
                'type': 'object',
                'properties': {
                  'status': {
                    'type': 'string',
                    'description': 'Status of SC',
                    'example': AppealsApi::SupplementalClaim::STATUSES.first,
                    'enum': AppealsApi::SupplementalClaim::STATUSES
                  },
                  'createdAt': {
                    'type': 'string',
                    'description': 'Created timestamp of the SC',
                    'example': '2020-12-16T19:52:23.909Z'
                  },
                  'updatedAt': {
                    'type': 'string',
                    'description': 'Updated timestamp of the SC',
                    'example': '2020-12-16T19:52:23.909Z'
                  }
                }
              },
              'formData': { '$ref': "#{ref_root}/scCreate" }
            }
          },
          'included': {
            'type': 'array',
            'items': {
              '$ref': "#{ref_root}/contestableIssue"
            }
          }
        }
      },
      'scEvidenceSubmissionResponse': {
        'type': 'object',
        'properties': {
          'data': {
            'properties': {
              'id': {
                'description': 'The document upload identifier',
                'type': 'string',
                'format': 'uuid',
                'example': '6d8433c1-cd55-4c24-affd-f592287a7572'
              },
              'type': {
                'description': 'JSON API type specification',
                'type': 'string',
                'example': 'evidenceSubmission'
              },
              'attributes': {
                'properties': {
                  'status': {
                    'type': 'string',
                    'example': VBADocuments::UploadSubmission::ALL_STATUSES.first,
                    'enum': VBADocuments::UploadSubmission::ALL_STATUSES
                  },
                  'code': {
                    'type': 'string',
                    'nullable': true
                  },
                  'detail': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Human readable error detail. Only present if status = "error"'
                  },
                  'appealType': {
                    'description': 'Type of associated appeal',
                    'type': 'string',
                    'example': 'SupplementalClaim'
                  },
                  'appealId': {
                    'description': 'GUID of associated appeal',
                    'type': 'string',
                    'format': 'uuid',
                    'example': '2926ad2a-9372-48cf-8ec1-69e08e4799ef'
                  },
                  'location': {
                    'type': 'string',
                    'nullable': true,
                    'description': 'Location to which to PUT document Payload',
                    'format': 'uri',
                    'example': 'https://sandbox-api.va.gov/example_path_here/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
                  },
                  'updatedAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  },
                  'createdAt': {
                    'description': 'The last time the submission was updated',
                    'type': 'string',
                    'format': 'date-time',
                    'example': '2018-07-30T17:31:15.958Z'
                  }
                }
              }
            },
            'required': %w[id type attributes]
          }
        },
        'required': ['data']
      }
    }
  end

  def sc_alternate_signer_schemas(ref_root)
    # Taken from 200995_headers.json
    {
      'X-Alternate-Signer-First-Name': {
        'description': 'Alternate signer\'s first name',
        'type': 'string',
        'minLength': 1,
        'maxLength': 30
      },
      'X-Alternate-Signer-Middle-Initial': {
        'description': 'Alternate signer\'s middle initial',
        'minLength': 1,
        'maxLength': 1,
        '$ref': "#{ref_root}/#{nbs_key}"
      },
      'X-Alternate-Signer-Last-Name': {
        'description': 'Alternate signer\'s last name',
        'minLength': 1,
        'maxLength': 40,
        '$ref': "#{ref_root}/#{nbs_key}"
      }
    }
  end

  def legacy_appeals_schema(ref_root)
    {
      'legacyAppeals': {
        'type': 'object',
        'properties': {
          'data': {
            'type': 'array',
            'items': {
              '$ref': "#{ref_root}/legacyAppeal"
            }
          }
        }
      },
      'legacyAppeal': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'legacy_appeal.json')))
    }
  end

  def shared_schemas
    # Keys are strings to override older, non-shared-schema definitions
    {
      'address': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'address.json')))['properties']['address'],
      'non_blank_string': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'non_blank_string.json')))['properties']['nonBlankString'],
      'phone': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'phone.json')))['properties']['phone'],
      'timezone': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'timezone.json')))['properties']['timezone']
    }
  end

  def parse_create_schema(version, schema_file, return_raw: false)
    file = File.read(AppealsApi::Engine.root.join('config', 'schemas', version, schema_file))
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
