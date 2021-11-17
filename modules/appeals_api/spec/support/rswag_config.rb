# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
class AppealsApi::RswagConfig
  def config
    {
      'modules/appeals_api/app/swagger/appeals_api/v2/swagger.json' => {
        openapi: '3.0.0',
        info: {
          title: 'Decision Reviews',
          version: 'v2',
          termsOfService: 'https://developer.va.gov/terms-of-service',
          description: File.read(AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'v2', 'api_description.md'))
        },
        tags: [
          {
            name: 'Higher-Level Reviews',
            description: ''
          },
          {
            name: 'Notice of Disagreements',
            description: ''
          },
          {
            name: 'Supplemental Claims',
            description: ''
          },
          {
            name: 'Contestable Issues',
            description: ''
          },
          {
            name: 'Legacy Appeals',
            description: ''
          }
        ],
        paths: {},
        basePath: '/services/appeals/v2/decision_reviews',
        components: {
          securitySchemes: {
            apikey: {
              type: :apiKey,
              name: :apikey,
              in: :header
            }
          },
          schemas: [
            generic_schemas('#/components/schemas'),
            hlr_v2_create_schemas,
            hlr_v2_response_schemas('#/components/schemas'),
            contestable_issues_schema('#/components/schemas'),
            nod_create_schemas,
            nod_response_schemas('#/components/schemas'),
            sc_create_schemas,
            sc_response_schemas('#/components/schemas'),
            legacy_appeals_schema('#/components/schemas')
          ].reduce(&:merge).sort_by { |k, _| k.to_s.downcase }.to_h
        },
        servers: [
          {
            url: 'https://sandbox-api.va.gov/services/appeals/{version}/decision_reviews',
            description: 'VA.gov API sandbox environment',
            variables: {
              version: {
                default: 'v2'
              }
            }
          },
          {
            url: 'https://api.va.gov/services/appeals/{version}/decision_reviews',
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

  def generic_schemas(ref_root)
    {
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
      'documentUploadMetadata': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'document_upload_metadata.json'))),
      'X-VA-SSN': {
        'allOf': [
          { 'description': 'social security number' },
          {
            'type': 'string',
            'minLength': 0,
            'maxLength': 9,
            'pattern': '^[0-9]{9}$'
          }
        ]
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
          { '$ref': "#{ref_root}/nonBlankString" }
        ]
      },
      'X-VA-Last-Name': {
        'allOf': [
          { 'description': 'last name' },
          { '$ref': "#{ref_root}/nonBlankString" }
        ]
      },
      'X-VA-Birth-Date': {
        'allOf': [
          { 'description': 'birth date' },
          { 'minLength': 10 },
          { 'maxLength': 10 },
          { '$ref': "#{ref_root}/date" }
        ]
      },
      'X-VA-File-Number': {
        'allOf': [
          { 'description': 'VA file number (c-file / css)' },
          { 'maxLength': 9 },
          { '$ref': "#{ref_root}/nonBlankString" }
        ]
      },
      'X-Consumer-Username': {
        'allOf': [
          { 'description': 'Consumer Username (passed from Kong)' },
          { '$ref': "#{ref_root}/nonBlankString" }
        ]
      },
      'X-Consumer-ID': {
        'allOf': [
          { 'description': 'Consumer GUID' },
          { '$ref': "#{ref_root}/nonBlankString" }
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
    parse_create_schema('v2', '200996.json')
  end

  def hlr_v2_response_schemas(ref_root)
    {
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
                    '$ref': "#{ref_root}/timeStamp"
                  },
                  'createdAt': {
                    '$ref': "#{ref_root}/timeStamp"
                  },
                  'formData': {
                    '$ref': "#{ref_root}/hlrCreate"
                  }
                }
              }
            },
            'required': %w[id type attributes]
          }
        },
        'required': ['data']
      },
      'hlrContestableIssuesShow': {
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
    }
  end

  def nod_create_schemas
    parse_create_schema('v1', '10182.json')
  end

  def nod_response_schemas(ref_root)
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
                '$ref': "#{ref_root}/nodCreateRoot"
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
      'evidenceSubmissionResponse': {
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

  def parse_create_schema(version, schema_file)
    file = File.read(AppealsApi::Engine.root.join('config', 'schemas', version, schema_file))
    file.gsub! '#/definitions/', '#/components/schemas/'
    schema = JSON.parse file
    schema['definitions']
  end
end
# rubocop:enable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
