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
            generic_schemas,
            hlr_v2_schemas('#/components/schemas'),
            contestable_issues_schema,
            nod_schemas('#/components/schemas')
          ].reduce(&:merge)
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

  def generic_schemas
    {
      'nonBlankString': {
        'type': 'string',
        'pattern': '[^ \\f\\n\\r\\t\\v\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff]',
        '$comment': "The pattern used ensures that a string has at least one non-whitespace character. The pattern comes from JavaScript's \\s character class. \"\\s Matches a single white space character, including space, tab, form feed, line feed, and other Unicode spaces. Equivalent to [ \\f\\n\\r\\t\\v\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff].\": https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions/Character_Classes  We are using simple character classes at JSON Schema's recommendation: https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-4.3"
      },
      'date': {
        'type': 'string',
        'pattern': '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      }
    }
  end

  def contestable_issues_schema
    {
      'contestableIssues': {
        'type': 'object',
        'properties': {
          'data': {
            'type': 'array',
            'items': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'contestable_issue.json')))
          }
        }
      }
    }
  end

  def hlr_v2_schemas(ref_root)
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
                        'additionalProperties': false
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
                      'timezone': JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'time_zones.json')))
                    },
                    'additionalProperties': false,
                    'required': [
                      'homeless'
                    ]
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
      }
    }
  end

  def nod_schemas(ref_root)
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
                    'decisionDate': { '$ref': "#{ref_root}/date" },
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
      }
    }
  end
end
# rubocop:enable Metrics/MethodLength, Layout/LineLength, Metrics/ClassLength
