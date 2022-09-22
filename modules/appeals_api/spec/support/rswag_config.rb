# frozen_string_literal: true

require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
class AppealsApi::RswagConfig
  include DocHelpers

  def config
    {
      "modules/appeals_api/app/swagger/appeals_api/v2/swagger#{DocHelpers.doc_suffix}.json" => {
        openapi: '3.0.0',
        info: {
          title: DocHelpers.doc_title,
          version: 'v2',
          termsOfService: 'https://developer.va.gov/terms-of-service',
          description: File.read(AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'v2', "api_description#{DocHelpers.doc_suffix}.md"))
        },
        tags: DocHelpers.doc_tags,
        paths: {},
        basePath: DocHelpers.doc_basepath('v2'),
        components: {
          securitySchemes: {
            apikey: {
              type: :apiKey,
              name: :apikey,
              in: :header
            }
          },
          schemas: schemas
        },
        servers: [
          {
            url: "https://sandbox-api.va.gov#{DocHelpers.doc_basepath}",
            description: 'VA.gov API sandbox environment',
            variables: {
              version: {
                default: 'v2'
              }
            }
          },
          {
            url: "https://api.va.gov#{DocHelpers.doc_basepath}",
            description: 'VA.gov API production environment',
            variables: {
              version: {
                default: 'v2'
              }
            }
          }
        ]
      }
    }
  end

  private

  def schemas
    a = []
    case ENV['RSWAG_SECTION_SLUG']
    when 'hlr'
      a << hlr_v2_create_schemas
      a << hlr_v2_response_schemas('#/components/schemas')
      a << contestable_issues_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas')
      a << shared_schemas
    when 'nod'
      a << nod_v2_create_schemas
      a << nod_v2_response_schemas('#/components/schemas')
      a << contestable_issues_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas')
      a << shared_schemas
    when 'sc'
      a << sc_create_schemas
      a << sc_response_schemas('#/components/schemas')
      a << contestable_issues_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas')
      a << shared_schemas
    when 'contestable_issues'
      a << contestable_issues_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas').slice(*%i[errorModel errorWithTitleAndDetail X-VA-SSN X-VA-File-Number])
      a << shared_schemas.slice(*%i[non_blank_string])
    when 'legacy_appeals'
      a << legacy_appeals_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas').slice(*%i[errorModel errorWithTitleAndDetail X-VA-SSN X-VA-File-Number])
      a << shared_schemas.slice(*%i[non_blank_string])
    else
      a << hlr_v2_create_schemas
      a << hlr_v2_response_schemas('#/components/schemas')
      a << nod_v2_create_schemas
      a << nod_v2_response_schemas('#/components/schemas')
      a << sc_create_schemas
      a << sc_response_schemas('#/components/schemas')
      a << contestable_issues_schema('#/components/schemas')
      a << legacy_appeals_schema('#/components/schemas')
      a << generic_schemas('#/components/schemas')
    end

    a.reduce(&:merge).sort_by { |k, _| k.to_s.downcase }.to_h
  end

  def generic_schemas(ref_root)
    nbs_ref = DocHelpers.wip_doc_enabled?(:segmented_apis, true) ? "#{ref_root}/non_blank_string" : "#{ref_root}/nonBlankString"

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
      'X-VA-Claimant-First-Name': {
        'allOf': [
          { 'description': 'first name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Claimant-Middle-Initial': {
        'allOf': [
          { 'description': 'middle initial' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Claimant-Last-Name': {
        'allOf': [
          { 'description': 'last name' },
          { '$ref': nbs_ref }
        ]
      },
      'X-VA-Claimant-Birth-Date': {
        'description': "Claimant's birth date",
        'type': 'string',
        'format': 'date'
      },
      'X-VA-Claimant-SSN': {
        'description': 'social security number',
        'type': 'string',
        'minLength': 9,
        'maxLength': 9,
        'pattern': '^[0-9]{9}$'
      },
      'X-VA-File-Number': {
        'allOf': [
          { 'description': 'VA file number (c-file / css)' },
          { 'maxLength': 9 },
          { '$ref': nbs_ref }
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

    return schemas if ENV['RSWAG_SECTION_SLUG'].in?(%w[hlr])

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
      'contestableIssue': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'contestable_issue.json')))
    }
  end

  def hlr_v2_create_schemas
    file = DocHelpers.wip_doc_enabled?(:segmented_apis, true) ? '200996_with_shared_refs.json' : '200996.json'
    parse_create_schema('v2', file)
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
                          'type': %w[
                            integer
                            string
                          ],
                          'nullable': true,
                          'example': 'null'
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
    file = DocHelpers.wip_doc_enabled?(:segmented_apis, true) ? '10182_with_shared_refs.json' : '10182.json'
    parse_create_schema('v2', file)
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
                    'type': %i[string null]
                  },
                  'detail': {
                    'type': %i[string null],
                    'description': 'Human readable error detail. Only present if status = "error"'
                  },
                  'appealType': {
                    'description': 'Type of associated appeal',
                    'type': 'string',
                    'example': 'NoticeOfDisagreement'
                  },
                  'appealId': {
                    'description': 'GUID of associated appeal',
                    'type': 'uuid',
                    'example': '2926ad2a-9372-48cf-8ec1-69e08e4799ef'
                  },
                  'location': {
                    'type': %i[string null],
                    'description': 'Location to which to PUT document Payload',
                    'format': 'uri',
                    'example': 'https://sandbox-api.va.gov/example_path_here/{idpath}'
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
    parse_create_schema('v2', '200995.json')
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
                    'type': %i[string null]
                  },
                  'detail': {
                    'type': %i[string null],
                    'description': 'Human readable error detail. Only present if status = "error"'
                  },
                  'appealType': {
                    'description': 'Type of associated appeal',
                    'type': 'string',
                    'example': 'SupplementalClaim'
                  },
                  'appealId': {
                    'description': 'GUID of associated appeal',
                    'type': 'uuid',
                    'example': '2926ad2a-9372-48cf-8ec1-69e08e4799ef'
                  },
                  'location': {
                    'type': %i[string null],
                    'description': 'Location to which to PUT document Payload',
                    'format': 'uri',
                    'example': 'https://sandbox-api.va.gov/example_path_here/{idpath}'
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
    {
      'address': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'address.json')))['properties']['address'],
      'non_blank_string': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'non_blank_string.json')))['properties']['nonBlankString'],
      'phone': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'phone.json')))['properties']['phone'],
      'timezone': JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v1', 'timezone.json')))['properties']['timezone']
    }
  end

  def parse_create_schema(version, schema_file)
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

    schema['definitions']
  end
end
# rubocop:enable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
