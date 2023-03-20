# frozen_string_literal: true

require 'decision_review/schemas'
module Swagger
  module V1
    module Schemas
      module Appeals
        class SupplementalClaims
          include Swagger::Blocks

          VetsJsonSchema::SCHEMAS.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV')['definitions'].each do |k, v|
            v.delete('oneOf') if k == 'centralMailAddress'
            if k == 'scCreate'
              # remove draft-07 specific schema items, they won't validate with swagger
              attrs = v['properties']['data']['properties']['attributes']
              attrs['properties']['evidenceSubmission'].delete('if')
              attrs['properties']['evidenceSubmission'].delete('then')
              attrs['properties']['evidenceSubmission']['properties']['evidenceType'].delete('if')
              attrs['properties']['evidenceSubmission']['properties']['evidenceType'].delete('then')
              attrs['properties']['evidenceSubmission']['properties']['evidenceType'].delete('else')
              attrs.delete('allOf')
            end
            swagger_schema k, v
          end

          swagger_schema 'scCreate' do
            example VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV')
          end

          VetsJsonSchema::SCHEMAS.fetch('SC-SHOW-RESPONSE-200_V1')['definitions'].each do |k, v|
            swagger_schema(k == 'root' ? 'scShowRoot' : k, v) {}
          end

          swagger_schema 'scShowRoot' do
            example VetsJsonSchema::EXAMPLES.fetch('SC-SHOW-RESPONSE-200_V1')
          end

          swagger_schema 'scContestableIssues' do
            example VetsJsonSchema::EXAMPLES.fetch('DECISION-REVIEW-GET-CONTESTABLE-ISSUES-RESPONSE-200_V1')
          end
        end
      end
    end
  end
end
