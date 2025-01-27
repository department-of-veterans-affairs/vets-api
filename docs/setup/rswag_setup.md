# Swagger implementation is recommended. See these docs: https://depo-platform-documentation.scrollhelp.site/developer-docs/swagger-implementation 

## Rswag setup for Rails engine

To create a minimal implementation of Rswag in your team's Rails engine you will need to do the following (commented lines are only for explaining what specific things do and should be removed from your specific implementation):

- In `/spec/swagger_helper.rb` add your Rails Engine's name eg `AppealsApi` to the `config.openapi_specs` section.
- Create your Rswag config file in your engine's `spec/support` dir (eg `/modules/appeals_api/spec/support/rswag_config.rb`) a minimal configuration is as follows:

```ruby
# /modules/appeals_api/spec/support/rswag_config.rb

class AppealsApi::RswagConfig
  def config
    {
      'modules/appeals_api/app/swagger/appeals_api/v2/swagger.json' => {
        # ^ This path points to wherever you would like Rswag to save the generated swagger json file.
        openapi: '3.0.1',
        info: {
          title: 'Decision Reviews',
          version: 'v2',
          termsOfService: 'https://developer.va.gov/terms-of-service',
          description: File.read(AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'v2', 'api_description.md'))
          # ^ You could have the description inline, but saving it as a standalone file makes it easier to edit/manage
        },
        tags: [
          {
            name: 'Higher-Level Reviews',
            description: ''
          }
          # ^ These tags are used for grouping each individual endpoint in the swagger UI
        ],
        components: {
          securitySchemes: {
            # ^ add your relevant security schemes here
            apikey: {
              type: :apiKey,
              name: :apikey,
              in: :header
            }
          },
          schemas: {
            # ^ schemas that can be used across multiple Rswag specs
            'nonBlankString': {
              'type': 'string',
              'pattern': '[^ \\f\\n\\r\\t\\v\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff]',
              '$comment': "The pattern used ensures that a string has at least one non-whitespace character. The pattern comes from JavaScript's \\s character class. \"\\s Matches a single white space character, including space, tab, form feed, line feed, and other Unicode spaces. Equivalent to [ \\f\\n\\r\\t\\v\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff].\": https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions/Character_Classes  We are using simple character classes at JSON Schema's recommendation: https://tools.ietf.org/html/draft-handrews-json-schema-validation-01#section-4.3"
            }
          }
        },
        paths: {},
        servers: [
          # ^ Used in creating the 'Environment' drop-down for generating example curl commands
          {
            url: 'https://dev-api.va.gov/services/appeals/{version}/decision_reviews',
            description: 'VA.gov API sandbox environment',
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
end
```

- Add your engines rake task to `rakelib/rswag.rake` by copy and pasting the following (substituting your relevant Rails engine in):

```ruby
# rakelib/rswag.rake

namespace :rswag do

  # ...

  namespace :appeals_api do
    desc 'Generate rswag docs for appeals_api'
    task run: :environment do
      ENV['PATTERN'] = 'modules/appeals_api/spec/docs/**/*_spec.rb'
      # ^ specifies the path of the specs you'd like Rswag to run
      ENV['RAILS_MODULE'] = 'appeals_api'
      # ^ added to make Rswag only write out swagger json relevant to your Rails engine
      ENV['SWAGGER_DRY_RUN'] = '0'
      # ^ Turns off the dry Rswag option - https://github.com/rswag/rswag#dry-run-option
      Rake::Task['rswag:specs:swaggerize'].invoke
      # ^ call the actual rswag rake task
    end
  end
end
```

- Create a new spec file for your Rswag specs

```ruby
# /modules/appeals_api/spec/docs/v2/hlr_spec.rb

require 'swagger_helper'
# ^ standard Rswag helper
require Rails.root.join('spec', 'rswag_override.rb').to_s
# ^ Rswag overrides to allow for multiple body examples and only writing out relevant swagger json (instead of writing all swagger json files out every time Rswag is run).

require 'rails_helper'

describe 'Higher-Level Reviews', openapi_spec: 'modules/appeals_api/app/swagger/appeals_api/v2/swagger.json', type: :request do
  #                                           ^ this path needs to match one of the paths from your Rswag config
  #                                                                                                           ^ adding 'type: :request' makes sure that RSpec knows how to properly interpret your spec if it lives outside of the 'spec/requests' path

  path '/higher_level_reviews/{uuid}' do
    # ^ this should be the actual url fragment you want Rswag to make a request to

    let(:apikey) { 'apikey' }

    get 'Shows a specific Higher-Level Review. (a.k.a. the Show endpoint)' do
      tags 'Higher-Level Reviews'
      # ^ Which tag(s) should this example be nested in (from the rswag config)

      operationId 'showHlr'
      # ^ unique Id that will be used by the swagger UI

      security [
        { apikey: [] }
      ]
      # ^ relevant security schemes (from Rswag config)

      consumes 'application/json'
      produces 'application/json'

      parameter name: :uuid, in: :path, type: :string, description: 'Higher-Level Review UUID'
      #         ^ name's value is important - it will be set by its value in the 'response' section

      response '200', 'Info about a single Higher-Level Review' do
        schema type: :object,
          properties: {
            data: {
              properties: {
                id: {
                  type: :string,
                  pattern: '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
                },
                type: {
                  type: :string,
                  enum: ['higherLevelReview']
                },
                attributes: {
                  properties: {
                    status: {
                      type: :string,
                      example: AppealsApi::HlrStatus::V2_STATUSES.first,
                      enum: AppealsApi::HlrStatus::V2_STATUSES
                    },
                    updatedAt: {
                      type: :string,
                      pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z'
                    },
                    createdAt: {
                      type: :string,
                      pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z'
                    },
                    formData: {
                      '$ref' => '#/components/schemas/hlrCreate'
                    }
                  }
                }
              },
              required: %w[id type attributes]
            }
          },
          required: ['data']
          # schemas can be defined several ways:
          #   inline (as shown above):
          #       schema type: :object, ...
          #   referenced from the Rswag config:
          #       schema '$ref' => '#/components/schemas/errors_object'
          #   or loaded from plain json files:
          #       schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        let(:uuid) { create(:minimal_higher_level_review_v2).id }
        # ^ needs to match the parameters name otherwise you'll see a No method error for 'uuid' (or whatever your parameter is called)

        before do |example|
          submit_request(example.metadata)
          # ^ makes the actual request - using the built up url (fragment and basePath) and any parameters you have supplied
        end

        it 'returns a 200 response' do |example|
          assert_response_matches_metadata(example.metadata)
          # ^ asserts that the respose matches the schema you have supplied
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
              # ^ saves the actual response from the 'submit_request(example.metadata)' call in the before action
            }
          }
        end
      end

      response '404', 'Higher-Level Review not found' do
        schema JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'support', 'schemas', 'errors', '404.json')))

        let(:uuid) { 'invalid' }

        before do |example|
          submit_request(example.metadata)
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        it 'returns a 404 response' do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end
end
```

- Run the custom rake task you created earlier to run Rswag and generate the swagger json file `rake rswag:appeals_api:run`
- Serve the generated swagger from your doc controller:

```ruby
class AppealsApi::Docs::V2::DocsController < ApplicationController
  skip_before_action(:authenticate)

  def decision_reviews
    swagger = JSON.parse(File.read(AppealsApi::Engine.root.join('app/swagger/appeals_api/v2/swagger.json')))
    render json: swagger
  end
end
```


---

### Misc details

- Make sure that if you are creating any resources (FactoryBot or otherwise) they happen lazily (ie inside a `let`, `before`, or `it`). If you put them inside the `response` block (or anywhere else that gets evaluated on load) Rspec will evaluate and run them when it is loading all the files up for a suite run - and then because they were not created in the typical way they won't get cleaned up properly at the end of the spec run... This can lead to confusion if you use specific counts of that resource anywhere else in your specs.

- How to add multiple request bodies and responses to Rswag examples (examples truncated for brevity):


```ruby
# ...
describe 'Higher-Level Reviews', openapi_spec: 'modules/appeals_api/app/swagger/appeals_api/v2/swagger.json', type: :request do
  let(:apikey) { 'apikey' }

  path '/higher_level_reviews' do
    post 'Creates a new Higher-Level Review' do
      # tags, operationId, description, etc

      parameter name: :hlr_body, in: :body, schema: { '$ref' => '#/components/schemas/hlrCreate' }
      # =>            ^ as stated before the value passed to the name: parameter is important as you will need to set its value later)

      parameter in: :body, examples: {
        'minimum fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_minimum.json')))
        },
        'all fields used' => {
          value: JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996.json')))
        }
      }
      # ^ the value of keys in the examples hash will be used in the request bodies drop down selector

      parameter in: :header,
        type: :string,
        name: 'X-VA-SSN',
        required: true,
        description: 'Veteran\'s SSN'

      let(:'X-VA-SSN') { '000000000' }

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996_minimum.json')))
        end
        # ^ referencing the parameter named above (:hlr_body) so Rswag knows to send this json as the body of the request

        # schema ...

        before do |example|
          submit_request(example.metadata)
        end

        it 'minimum fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
              # ^ To have multiple responses (shown in the swagger UI via a drop down) you have to nest them under 'examples' instead of directly in 'example'
              #   You can set the text statically here or use the examples metadata from the 'it ... do' - in this case 'minimum fields used'. Providing that you don't over write it with a subsequent example.
            }
          }
        end
      end

      response '200', 'Info about a single Higher-Level Review' do
        let(:hlr_body) do
          JSON.parse(File.read(AppealsApi::Engine.root.join('spec', 'fixtures', 'v2', 'valid_200996.json')))
        end

        # schema ...

        before do |example|
          submit_request(example.metadata)
        end

        it 'all fields used' do |example|
          assert_response_matches_metadata(example.metadata)
        end
        # ^ This is another '200' response but because the description is different than the above '200' example it will show up as two different possible examples in the swagger UI

        after do |example|
          response_title = example.metadata[:description]
          example.metadata[:response][:content] = {
            'application/json' => {
              examples: {
                "#{response_title}": {
                  value: JSON.parse(response.body, symbolize_names: true)
                }
              }
            }
          }
        end
      end
    end
  end
end
```
