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
            hlr_v2_create_schemas('#/components/schemas'),
            hlr_v2_response_schemas('#/components/schemas'),
            contestable_issues_schema('#/components/schemas'),
            nod_create_schemas('#/components/schemas'),
            nod_response_schemas('#/components/schemas'),
            sc_create_schemas('#/components/schemas'),
            sc_response_schemas('#/components/schemas'),
            legacy_appeals_schema('#/components/schemas')
          ].reduce(&:merge).sort_by { |k, _| k.to_s.downcase }.to_h
        },
        paths: {},
        basePath: '/services/appeals/v2/decision_reviews',
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
      'nonBlankString': {
        'type': 'string',
        'pattern': '[^ \\f\\n\\r\\t\\v\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff]',
        '$comment': "The pattern used ensures that a string has at least one non-whitespace character. The pattern comes from JavaScript's \\s character class. \"\\s Matches a single white space character, including space, tab, form feed, line feed, and other Unicode spaces. Equivalent to [ \\f\\n\\r\\t\\v\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff].\": https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions/Character_Classes  We are using simple character classes at JSON Schema's recommendation: https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-4.3"
      },
      'date': {
        'type': 'string',
        'pattern': '^[0-9]{4}-[0-9]{2}-[0-9]{2}$',
        'maxLength': 10,
        'minLength': 10
      },
      'errorModel': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', 'default.json'))),
      'errorWithTitleAndDetail': {
        "type": 'array',
        "items": {
          "type": 'object',
          "properties": {
            "title": {
              "type": 'string'
            },
            "detail": {
              "type": 'string'
            }
          }
        }
      },
      'documentUploadMetadata': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'document_upload_metadata.json'))),
      "X-VA-SSN": {
        "allOf": [
          { "description": 'social security number' },
          {
            "type": 'string',
            "minLength": 0,
            "maxLength": 9,
            "pattern": '^[0-9]{9}$'
          }
        ]
      },
      "X-VA-First-Name": {
        "allOf": [
          { "description": 'first name' },
          { "type": 'string' }
        ]
      },
      "X-VA-Middle-Initial": {
        "allOf": [
          { "description": 'middle initial' },
          { "$ref": "#{ref_root}/nonBlankString" }
        ]
      },
      "X-VA-Last-Name": {
        "allOf": [
          { "description": 'last name' },
          { "$ref": "#{ref_root}/nonBlankString" }
        ]
      },
      "X-VA-Birth-Date": {
        "allOf": [
          { "description": 'birth date' },
          { "minLength": 10 },
          { "maxLength": 10 },
          { "$ref": "#{ref_root}/date" }
        ]
      },
      "X-VA-File-Number": {
        "allOf": [
          { "description": 'VA file number (c-file / css)' },
          { "maxLength": 9 },
          { "$ref": "#{ref_root}/nonBlankString" }
        ]
      },
      "X-Consumer-Username": {
        "allOf": [
          { "description": 'Consumer Username (passed from Kong)' },
          { "$ref": "#{ref_root}/nonBlankString" }
        ]
      },
      "X-Consumer-ID": {
        "allOf": [
          { "description": 'Consumer GUID' },
          { "$ref": "#{ref_root}/nonBlankString" }
        ]
      },
      "uuid": {
        "type": 'string',
        "pattern": '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
      },
      "timeStamp": {
        "type": 'string',
        "pattern": '\\d{4}(-\\d{2}){2}T\\d{2}(:\\d{2}){2}\\.\\d{3}Z'
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
              "$ref": "#{ref_root}/contestableIssue"
            }
          }
        }
      },
      'contestableIssue': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'contestable_issue.json')))
    }
  end

  def hlr_v2_create_schemas(ref_root)
    {
      'hlrCreatePhone': {
        'type': 'object',
        'properties': {
          'countryCode': {
            'type': 'string',
            'pattern': '^[0-9]+$',
            'minLength': 1,
            'maxLength': 3
          },
          'areaCode': {
            'type': 'string',
            'pattern': '^[2-9][0-9]{2}$',
            'minLength': 1,
            'maxLength': 4
          },
          'phoneNumber': {
            'type': 'string',
            'pattern': '^[0-9]{1,14}$',
            'minLength': 1,
            'maxLength': 14
          },
          'phoneNumberExt': {
            'type': 'string',
            'pattern': '^[a-zA-Z0-9]{1,10}$',
            'minLength': 1,
            'maxLength': 10
          }
        },
        'required': %w[
          areaCode
          phoneNumber
        ]
      },
      'hlrCreate': {
        'type': 'object',
        'properties': {
          'data': {
            'type': 'object',
            'properties': {
              'type': {
                'type': 'string',
                'enum': [
                  'higherLevelReview'
                ]
              },
              'attributes': {
                'description': 'If informal conference requested (`informalConference: true`), contact (`informalConferenceContact`) and time (`informalConferenceTime`) must be specified.',
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'informalConference': {
                    'type': 'boolean'
                  },
                  'benefitType': {
                    'type': 'string',
                    'enum': [
                      'compensation'
                    ]
                  },
                  'veteran': {
                    'type': 'object',
                    'properties': {
                      'homeless': {
                        'type': 'boolean'
                      },
                      'address': {
                        'type': 'object',
                        'properties': {
                          'addressLine1': {
                            'type': 'string',
                            'maxLength': 60
                          },
                          'addressLine2': {
                            'type': 'string',
                            'maxLength': 30
                          },
                          'addressLine3': {
                            'type': 'string',
                            'maxLength': 10
                          },
                          'city': {
                            'type': 'string',
                            'maxLength': 60
                          },
                          'stateCode': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'state_codes.json'))),
                          'countryCodeISO2': {
                            'type': 'string',
                            'pattern': '^[A-Z]{2}$'
                          },
                          'zipCode5': {
                            'type': 'string',
                            'description': '5-digit zipcode. Use "00000" if Veteran is outside the United States',
                            'pattern': '^[0-9]{5}$'
                          },
                          'internationalPostalCode': { 'type': 'string', 'maxLength': 16 }
                        },
                        'additionalProperties': false,
                        'required': %w[addressLine1 city countryCodeISO2 zipCode5]
                      },
                      'phone': {
                        '$ref': "#{ref_root}/hlrCreatePhone"
                      },
                      'email': {
                        'type': 'string',
                        'format': 'email',
                        'minLength': 6,
                        'maxLength': 255
                      },
                      # Generated using: File.write('timezones.json', (TZInfo::Timezone.all.map(&:name) + ActiveSupport::TimeZone.all.map(&:name)).uniq.sort) #Although this might seem like it should be generated dynamically, it's been written to file in case TZInfo or ActiveSupport deletes/modifies a timezone with a future version, which would change our APIs enum (a non-additve change to the current API version).
                      'timezone': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'time_zones.json')))
                    },
                    'additionalProperties': false,
                    'required': ['homeless'],
                    'if': { 'properties': { 'homeless': { 'const': false } } },
                    'then': { 'required': ['address'] }
                  },
                  'informalConferenceContact': {
                    'type': 'string',
                    'enum': %w[
                      veteran
                      representative
                    ]
                  },
                  'informalConferenceTime': {
                    'type': 'string',
                    'enum': [
                      '800-1200 ET',
                      '1200-1630 ET'
                    ]
                  },
                  'informalConferenceRep': {
                    'type': 'object',
                    'description': 'The Representative information listed MUST match the current Power of Attorney for the Veteran.  Any changes to the Power of Attorney must be submitted via a VA 21-22 form separately.',
                    'properties': {
                      'firstName': {
                        'type': 'string',
                        'maxLength': 30
                      },
                      'lastName': {
                        'type': 'string',
                        'maxLength': 40
                      },
                      'phone': {
                        '$ref': "#{ref_root}/hlrCreatePhone"
                      },
                      'email': {
                        'type': 'string',
                        'format': 'email',
                        'minLength': 6,
                        'maxLength': 255
                      }
                    },
                    'additionalProperties': false,
                    'required': %w[
                      firstName
                      lastName
                      phone
                    ]
                  },
                  'socOptIn': {
                    'type': 'boolean'
                  }
                },
                'required': %w[
                  informalConference
                  benefitType
                  veteran
                  socOptIn
                ],
                'if': {
                  'properties': {
                    'informalConference': {
                      'const': true
                    }
                  }
                },
                'then': {
                  'required': %w[
                    informalConferenceContact
                    informalConferenceTime
                  ]
                }
              }
            },
            'additionalProperties': false,
            'required': %w[
              type
              attributes
            ]
          },
          'included': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'type': {
                  'type': 'string',
                  'enum': [
                    'contestableIssue'
                  ]
                },
                'attributes': {
                  'type': 'object',
                  'properties': {
                    'issue': {
                      'allOf': [
                        {
                          '$ref': "#{ref_root}/nonBlankString"
                        },
                        {
                          'maxLength': 140
                        }
                      ]
                    },
                    'decisionDate': {
                      '$ref': "#{ref_root}/date"
                    },
                    'decisionIssueId': {
                      'type': 'integer'
                    },
                    'ratingIssueReferenceId': {
                      'type': 'string'
                    },
                    'ratingDecisionReferenceId': {
                      'type': 'string'
                    },
                    'socDate': {
                      '$ref': "#{ref_root}/date"
                    }
                  },
                  'additionalProperties': false,
                  'required': %w[
                    issue
                    decisionDate
                  ]
                }
              },
              'additionalProperties': false,
              'required': %w[
                type
                attributes
              ]
            },
            'minItems': 1,
            'uniqueItems': true
          }
        },
        'additionalProperties': false,
        'required': %w[
          data
          included
        ]
      },
      'hlrCreateParameters': {
        "type": 'object',
        "properties": {
          "X-VA-SSN": {
            "type": 'string',
            "description": "Veteran's SSN",
            "pattern": '^[0-9]{9}$'
          },
          "X-VA-First-Name": {
            "type": 'string',
            "description": "Veteran's first name",
            "maxLength": 30,
            "$comment": 'can be whitespace, to accommodate those with 1 legal name'
          },
          "X-VA-Middle-Initial": {
            "allOf": [
              { "description": "Veteran's middle initial", "maxLength": 1 },
              { "$ref": "#{ref_root}/nonBlankString" }
            ]
          },
          "X-VA-Last-Name": { "allOf": [
            { "description": "Veteran's last name", "maxLength": 40 },
            { "$ref": "#{ref_root}/nonBlankString" }
          ] },
          "X-VA-Birth-Date": { "allOf": [
            { "description": "Veteran's birth date" },
            { "$ref": "#{ref_root}/date" }
          ] },
          "X-VA-File-Number": { "allOf": [
            { "description": "Veteran's file number", "maxLength": 9 },
            { "$ref": "#{ref_root}/nonBlankString" }
          ] },
          "X-VA-Insurance-Policy-Number": { "allOf": [
            { "description": "Veteran's insurance policy number", "maxLength": 18 },
            { "$ref": "#{ref_root}/nonBlankString" }
          ] },
          "X-Consumer-Username": {
            "allOf": [
              { "description": 'Consumer User Name (passed from Kong)' },
              { "$ref": "#{ref_root}/nonBlankString" }
            ]
          },
          "X-Consumer-ID": { "allOf": [
            { "description": 'Consumer GUID' },
            { "$ref": "#{ref_root}/nonBlankString" }
          ] }
        },
        "additionalProperties": false,
        "required": %w[
          X-VA-SSN
          X-VA-First-Name
          X-VA-Last-Name
          X-VA-Birth-Date
        ]
      }
    }
  end

  def hlr_v2_response_schemas(ref_root)
    {
      "hlrShow": {
        "type": 'object',
        "properties": {
          "data": {
            "properties": {
              "id": {
                '$ref': "#{ref_root}/uuid"
              },
              "type": {
                "type": 'string',
                "enum": ['higherLevelReview']
              },
              "attributes": {
                "properties": {
                  "status": {
                    "type": 'string',
                    "example": AppealsApi::HlrStatus::V2_STATUSES.first,
                    "enum": AppealsApi::HlrStatus::V2_STATUSES
                  },
                  "updatedAt": {
                    '$ref': "#{ref_root}/timeStamp"
                  },
                  "createdAt": {
                    '$ref': "#{ref_root}/timeStamp"
                  },
                  "formData": {
                    '$ref' => "#{ref_root}/hlrCreate"
                  }
                }
              }
            },
            "required": %w[id type attributes]
          }
        },
        "required": ['data']
      },
      "hlrContestableIssuesShow": {
        "type": 'object',
        "properties": {
          "data": {
            "type": 'array',
            "items": {
              "type": 'object',
              "description": 'A contestable issue (to contest this, you include it as a RequestIssue when creating a HigherLevelReview, SupplementalClaim, or Appeal)',
              "properties": {
                "type": {
                  "type": 'string',
                  "enum": [
                    'contestableIssue'
                  ]
                },
                "id": {
                  "type": 'string',
                  "nullable": true
                },
                "attributes": {
                  "type": 'object',
                  "properties": {
                    "ratingIssueReferenceId": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'RatingIssue ID',
                      "example": '2385'
                    },
                    "ratingIssueProfileDate": {
                      "type": 'string',
                      "nullable": true,
                      "format": 'date',
                      "description": '(yyyy-mm-dd) RatingIssue profile date',
                      "example": '2006-05-31'
                    },
                    "ratingIssueDiagnosticCode": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'RatingIssue diagnostic code',
                      "example": '5005'
                    },
                    "ratingDecisionReferenceId": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'The BGS ID for the contested rating decision. This may be populated while ratingIssueReferenceId is nil',
                      "example": 'null'
                    },
                    "decisionIssueId": {
                      "type": 'integer',
                      "nullable": true,
                      "description": 'DecisionIssue ID',
                      "example": 'null'
                    },
                    "approxDecisionDate": {
                      "type": 'string',
                      "nullable": true,
                      "format": 'date',
                      "description": '(yyyy-mm-dd) Approximate decision date',
                      "example": '2006-11-27'
                    },
                    "description": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'Description',
                      "example": 'Service connection for hypertension is granted with an evaluation of 10 percent effective July 24, 2005.'
                    },
                    "rampClaimId": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'RampClaim ID',
                      "example": 'null'
                    },
                    "titleOfActiveReview": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'Title of DecisionReview that this issue is still active on',
                      "example": 'null'
                    },
                    "sourceReviewType": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'The type of DecisionReview (HigherLevelReview, SupplementalClaim, Appeal) the issue was last decided on (if any)',
                      "example": 'null'
                    },
                    "timely": {
                      "type": 'boolean',
                      "description": 'An issue is timely if the receipt date is within 372 dates of the decision date.',
                      "example": false
                    },
                    "latestIssuesInChain": {
                      "type": 'array',
                      "description": 'Shows the chain of decision and rating issues that preceded this issue. Only the most recent issue can be contested (the object itself that contains the latestIssuesInChain attribute).',
                      "items": {
                        "type": 'object',
                        "properties": {
                          "id": {
                            "type": %w[
                              integer
                              string
                            ],
                            "nullable": true,
                            "example": 'null'
                          },
                          "approxDecisionDate": {
                            "type": 'string',
                            "nullable": true,
                            "format": 'date',
                            "example": '2006-11-27'
                          }
                        }
                      }
                    },
                    "ratingIssueSubjectText": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'Short description of RatingIssue',
                      "example": 'Hypertension'
                    },
                    "ratingIssuePercentNumber": {
                      "type": 'string',
                      "nullable": true,
                      "description": 'Numerical rating for RatingIssue',
                      "example": '10'
                    },
                    "isRating": {
                      "type": 'boolean',
                      "description": 'Whether or not this is a RatingIssue',
                      "example": true
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

  def nod_create_schemas(ref_root)
    {
      'nodCreateRoot': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'data': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'type': { 'type': 'string', 'enum': ['noticeOfDisagreement'] },
              'attributes': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'veteran': {
                    'type': 'object',
                    'additionalProperties': false,
                    'properties': {
                      'homeless': { 'type': 'boolean' },
                      'address': {
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {
                          'addressLine1': { 'type': 'string' },
                          'addressLine2': { 'type': 'string' },
                          'addressLine3': { 'type': 'string' },
                          'city': { 'type': 'string' },
                          'stateCode': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'state_codes.json'))),
                          'countryName': { 'type': 'string' },
                          'zipCode5': {
                            'type': 'string',
                            'pattern': '^[0-9]{5}$',
                            'minLength': 5, 'maxLength': 5,
                            'description': '5-digit zipcode. Use "00000" if Veteran is outside the United States'
                          },
                          'internationalPostalCode': { 'type': 'string' }
                        },
                        'required': %w[addressLine1 city countryName zipCode5]
                      },
                      'phone': {
                        '$comment': 'the phone fields must not exceed 20 chars, when concatenated',
                        'type': 'object',
                        'additionalProperties': false,
                        'properties': {
                          'countryCode': { 'type': 'string', 'pattern': '^[0-9]+$', 'minLength': 1, 'maxLength': 3 },
                          'areaCode': { 'type': 'string', 'pattern': '^[0-9]{1,4}$', 'minLength': 1, 'maxLength': 4 },
                          'phoneNumber': { 'type': 'string', 'pattern': '^[0-9]{1,14}$', 'minLength': 1, 'maxLength': 14 },
                          'phoneNumberExt': { 'type': 'string', 'pattern': '^[a-zA-Z0-9]{1,10}$', 'minLength': 1, 'maxLength': 10 }
                        },
                        'required': %w[areaCode phoneNumber]
                      },
                      'emailAddressText': { 'type': 'string', 'minLength': 6, 'maxLength': 255, 'format': 'email' },
                      'representativesName': { 'type': 'string', 'maxLength': 120 }
                    },
                    'required': %w[homeless phone emailAddressText],
                    'if': { 'properties': { 'homeless': { 'const': false } } },
                    'then': { 'required': ['address'] }
                  },
                  'boardReviewOption': { 'type': 'string', 'enum': %w[direct_review evidence_submission hearing] },
                  'hearingTypePreference': { 'type': 'string', 'enum': %w[virtual_hearing video_conference central_office] },
                  # Generated using: File.write('timezones.json', (TZInfo::Timezone.all.map(&:name) + ActiveSupport::TimeZone.all.map(&:name)).uniq.sort) #Although this might seem like it should be generated dynamically, it's been written to file in case TZInfo or ActiveSupport deletes/modifies a timezone with a future version, which would change our APIs enum (a non-additve change to the current API version).
                  'timezone': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'time_zones.json'))),
                  'socOptIn': { 'type': 'boolean' }
                },
                'required': %w[boardReviewOption socOptIn]
              }
            },
            'required': %w[type attributes]
          },
          'included': {
            'type': 'array',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'type': { 'type': 'string', 'enum': ['contestableIssue'] },
                'attributes': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'issue': { '$ref': "#{ref_root}/nonBlankString", 'maxLength': 180 },
                    'decisionDate': { '$ref': "#{ref_root}/nodCreateHeadersDate" },
                    'decisionIssueId': { 'type': 'integer' },
                    'ratingIssueReferenceId': { 'type': 'string' },
                    'ratingDecisionReferenceId': { 'type': 'string' },
                    'disagreementArea': { 'type': 'string', 'maxLength': 90 }
                  },
                  'required': %w[issue decisionDate]
                }
              },
              'required': %w[type attributes]
            },
            'minItems': 1,
            'maxItems': 100,
            'uniqueItems': true
          }
        },
        'required': %w[data included]
      },
      "nodCreateHeadersDate": {
        "type": 'string',
        "pattern": '^[0-9]{4}(-[0-9]{2}){2}$'
      },
      "nodCreateHeadersRoot": {
        "type": 'object',
        "additionalProperties": false,
        "properties": {
          "X-VA-First-Name": {
            "$ref": "#{ref_root}/X-VA-First-Name"
          },
          "X-VA-Middle-Initial": {
            "$ref": "#{ref_root}/X-VA-Middle-Initial"
          },
          "X-VA-Last-Name": {
            "$ref": "#{ref_root}/X-VA-Last-Name"
          },
          "X-VA-SSN": {
            "$ref": "#{ref_root}/X-VA-SSN"
          },
          "X-VA-File-Number": {
            "$ref": "#{ref_root}/X-VA-File-Number"
          },
          "X-VA-Birth-Date": {
            "$ref": "#{ref_root}/X-VA-Birth-Date"
          },
          "X-Consumer-Username": {
            "$ref": "#{ref_root}/X-Consumer-Username"
          },
          "X-Consumer-ID": {
            "$ref": "#{ref_root}/X-Consumer-ID"
          }
        },
        "required": %w[
          X-VA-First-Name
          X-VA-Last-Name
          X-VA-SSN
          X-VA-Birth-Date
        ]
      }
    }
  end

  def nod_response_schemas(ref_root)
    {
      "nodCreateResponse": {
        "description": 'Successful response of a 10182 form submission',
        "type": 'object',
        "properties": {
          "data": {
            "properties": {
              "id": {
                "type": 'string',
                "description": 'Unique ID of created NOD',
                "example": '97751cb6-d06d-4179-87f6-75e3fc9d875c'
              },
              "type": {
                "type": 'string',
                "description": 'Name of record class',
                "example": 'noticeOfDisagreement'
              },
              "attributes": {
                "type": 'object',
                "properties": {
                  "status": {
                    "type": 'string',
                    "description": 'Status of NOD',
                    "example": AppealsApi::NodStatus::STATUSES.first,
                    "enum": AppealsApi::NodStatus::STATUSES
                  },
                  "createdAt": {
                    "type": 'string',
                    "description": 'Created timestamp of the NOD',
                    "example": '2020-12-16T19:52:23.909Z'
                  },
                  "updatedAt": {
                    "type": 'string',
                    "description": 'Updated timestamp of the NOD',
                    "example": '2020-12-16T19:52:23.909Z'
                  }
                }
              },
              "formData": {
                "$ref": "#{ref_root}/nodCreateRoot"
              }
            }
          },
          "included": {
            "type": 'array',
            "items": {
              "$ref": "#{ref_root}/contestableIssue"
            }
          }
        }
      },
      "evidenceSubmissionResponse": {
        "type": 'object',
        "properties": {
          "data": {
            "properties": {
              "id": {
                "description": 'The document upload identifier',
                "type": 'string',
                "format": 'uuid',
                "example": '6d8433c1-cd55-4c24-affd-f592287a7572'
              },
              "type": {
                "description": 'JSON API type specification',
                "type": 'string',
                "example": 'evidenceSubmission'
              },
              "attributes": {
                "properties": {
                  "status": {
                    "type": 'string',
                    "example": VBADocuments::UploadSubmission::ALL_STATUSES.first,
                    "enum": VBADocuments::UploadSubmission::ALL_STATUSES
                  },
                  "code": {
                    "type": %i[string null]
                  },
                  "detail": {
                    "type": %i[string null],
                    "description": 'Human readable error detail. Only present if status = "error"'
                  },
                  "appealType": {
                    "description": 'Type of associated appeal',
                    "type": 'string',
                    "example": 'NoticeOfDisagreement'
                  },
                  "appealId": {
                    "description": 'GUID of associated appeal',
                    "type": 'uuid',
                    "example": '2926ad2a-9372-48cf-8ec1-69e08e4799ef'
                  },
                  "location": {
                    "type": %i[string null],
                    "description": 'Location to which to PUT document Payload',
                    "format": 'uri',
                    "example": 'https://sandbox-api.va.gov/example_path_here/{idpath}'
                  },
                  "updatedAt": {
                    "description": 'The last time the submission was updated',
                    "type": 'string',
                    "format": 'date-time',
                    "example": '2018-07-30T17:31:15.958Z'
                  },
                  "createdAt": {
                    "description": 'The last time the submission was updated',
                    "type": 'string',
                    "format": 'date-time',
                    "example": '2018-07-30T17:31:15.958Z'
                  }
                }
              }
            },
            "required": %w[id type attributes]
          }
        },
        "required": ['data']
      }
    }
  end

  def sc_create_schemas(ref_root)
    {
      'scCreate': {
        'type': 'object',
        'properties': {
          'data': {
            'type': 'object',
            'properties': {
              'type': { 'type': 'string', 'enum': ['supplementalClaim'] },
              'attributes': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'benefitType': { 'type': 'string', 'enum': %w[compensation pensionSurvivorsBenefits fiduciary lifeInsurance veteransHealthAdministration veteranReadinessAndEmployment loanGuaranty education nationalCemeteryAdministration] },
                  'veteran': {
                    'type': 'object',
                    'properties': {
                      'address': { 'type': 'object',
                                   'properties': {
                                     'addressLine1': { 'type': 'string', 'maxLength': 60 },
                                     'addressLine2': { 'type': 'string', 'maxLength': 30 },
                                     'addressLine3': { 'type': 'string', 'maxLength': 10 },
                                     'city': { 'type': 'string', 'maxLength': 60 },
                                     'stateCode': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'state_codes.json'))),
                                     'countryCodeISO2': { 'type': 'string', 'pattern': '^[A-Z]{2}$' },
                                     'zipCode5': {
                                       'type': 'string',
                                       'description': "5-digit zipcode. Use '00000' if Veteran is outside the United States",
                                       'pattern': '^[0-9]{5}$'
                                     }
                                   },
                                   'additionalProperties': false,
                                   'required': %w[addressLine1 city countryCodeISO2 zipCode5] },
                      'phone': {
                        'type': 'object',
                        'properties': {
                          'countryCode': { 'type': 'string', 'pattern': '^[0-9]+$' },
                          'areaCode': { 'type': 'string', 'pattern': '^[2-9][0-9]{2}$' },
                          'phoneNumber': { 'type': 'string', 'pattern': '^[0-9]{1,14}$' },
                          'phoneNumberExt': { 'type': 'string', 'pattern': '^[0-9]{1,10}$' }
                        },
                        'required': %w[areaCode phoneNumber]
                      },
                      'email': { 'type': 'string', 'format': 'email', 'minLength': 6, 'maxLength': 255 },
                      'timezone': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'time_zones.json')))
                    },
                    'additionalProperties': false,
                    'required': []
                  },
                  'evidenceSubmission': {
                    'type': 'object',
                    'properties': {
                      'evidenceType': {
                        'type': 'array',
                        'items': { 'enum': %w[upload retrieval] },
                        'minItems': 1,
                        'uniqueItems': true
                      },
                      'retrieveFrom': {
                        'type': 'array',
                        'items': {
                          'type': 'object',
                          'properties': {
                            'type': { 'type': 'string', 'enum': ['retrievalEvidence'] },
                            'attributes': {
                              'type': 'object',
                              'properties': {
                                'locationAndName': { '$ref': "#{ref_root}/nonBlankString" },
                                'evidenceDates': {
                                  'type': 'array',
                                  'items': { '$ref': "#{ref_root}/date" },
                                  'minItems': 1,
                                  'maxItems': 8
                                }
                              },
                              'additionalProperties': false,
                              'required': %w[locationAndName evidenceDates]
                            }
                          },
                          'additionalProperties': false,
                          'required': %w[type attributes]
                        },
                        'minItems': 1,
                        'uniqueItems': true
                      }
                    },
                    'required': ['evidenceType'],
                    'anyOf': [
                      {
                        'not': {
                          'properties': {
                            'evidenceType': { 'contains': { 'enum': ['retrieval'] } }
                          }
                        }
                      },
                      { 'required': ['retrieveFrom'] }
                    ]
                  },
                  'noticeAcknowledgement': {
                    'enum': [true, false]
                  },
                  'socOptIn': { 'type': 'boolean' }
                },
                'required': %w[veteran evidenceSubmission socOptIn noticeAcknowledgement],
                'if': { 'properties': { 'benefitType': { 'const': 'compensation' } } },
                'then': { 'properties': { 'noticeAcknowledgement': { 'const': true } } }
              }
            },
            'additionalProperties': false,
            'required': %w[type attributes]
          },
          'included': {
            'type': 'array',
            'items': { 'type': 'object',
                       'properties': {
                         'type': { 'type': 'string', 'enum': ['contestableIssue'] },
                         'attributes': {
                           'type': 'object',
                           'properties': {
                             'issue': { 'allOf': [{ '$ref': "#{ref_root}/nonBlankString" }, { 'maxLength': 140 }] },
                             'decisionDate': { '$ref': "#{ref_root}/date" },
                             'decisionIssueId': { 'type': 'integer' },
                             'ratingIssueReferenceId': { 'type': 'string' },
                             'ratingDecisionReferenceId': { 'type': 'string' },
                             'socDate': { '$ref': "#{ref_root}/date" }
                           },
                           'additionalProperties': false,
                           'required': %w[issue decisionDate]
                         }
                       },
                       'additionalProperties': false,
                       'required': %w[type attributes] },
            'minItems': 1,
            'uniqueItems': true
          }
        },
        'additionalProperties': false,
        'required': %w[data included]
      }
    }
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
              "$ref": "#{ref_root}/legacyAppeal"
            }
          }
        }
      },
      'legacyAppeal': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'legacy_appeal.json')))
    }
  end
end
# rubocop:enable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
