require 'evss/disability_compensation_auth_headers'
require 'evss/auth_headers'
require 'claims_api/special_issue_mappers/bgs'

module ClaimsApi
  module V2
    module Forms
      class DisabilityCompensation < ClaimsApi::V2::Base
        version 'v2'
        helpers do
          def form_attributes
            params.dig('data', 'attributes') || {}
          end

          def auth_headers
            evss_headers = EVSS::DisabilityCompensationAuthHeaders
                           .new(target_veteran)
                           .add_headers(
                             EVSS::AuthHeaders.new(target_veteran).to_h
                           )
          end

          def flashes
            initial_flashes = form_attributes.dig('veteran', 'flashes')
            homelessness = form_attributes.dig('veteran', 'homelessness')
            is_terminally_ill = form_attributes.dig('veteran', 'isTerminallyIll')

            initial_flashes.push('Homeless') if homelessness.present?
            initial_flashes.push('Terminally Ill') if is_terminally_ill.present? && is_terminally_ill

            initial_flashes.present? ? initial_flashes.uniq : []
          end

          def special_issues_per_disability
            (form_attributes['disabilities'] || []).map { |disability| special_issues_for_disability(disability) }
          end

          def special_issues_for_disability(disability)
            primary_special_issues = disability['specialIssues'] || []
            secondary_special_issues = []
            (disability['secondaryDisabilities'] || []).each do |secondary_disability|
              secondary_special_issues += (secondary_disability['specialIssues'] || [])
            end
            special_issues = primary_special_issues + secondary_special_issues

            mapper = ClaimsApi::SpecialIssueMapper.new
            {
              code: disability['diagnosticCode'],
              name: disability['name'],
              special_issues: special_issues.map { |special_issue| mapper.code_from_name(special_issue) }
            }
          end
        end

        before do
          authenticate
          permit_scopes %w[claim.write]
        end

        resource 'veterans/:veteranId' do
          resource 'forms/21-526EZ' do
            desc 'Submit a claim.' do
              success code: 202, model: ClaimsApi::Entities::V2::DisabilityClaimSubmittedEntity
              failure [
                [401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity'],
                [400, 'Bad Request', 'ClaimsApi::Entities::V2::ErrorsEntity']
              ]
              tags ['Forms']
              security [{ bearer_token: [] }]
            end
            params do
              requires :token, type: String
              requires :data, type: Hash do
                optional :type, type: String, documentation: { param_type: 'body' }
                requires :attributes, type: Hash do
                  requires :veteran, type: Hash do
                    requires :currentlyVAEmployee, type: Boolean
                    # TODO: define necessary schema here
                  end
                end
              end
            end
            post '/' do
              status 202

              auto_claim = ClaimsApi::AutoEstablishedClaim.create(
                status: ClaimsApi::AutoEstablishedClaim::PENDING,
                auth_headers: auth_headers,
                form_data: form_attributes,
                flashes: flashes,
                special_issues: special_issues_per_disability,
                source: source_name
              )
              unless auto_claim.id
                existing_auto_claim = ClaimsApi::AutoEstablishedClaim.find_by(md5: auto_claim.md5, source: source_name)
                auto_claim = existing_auto_claim if existing_auto_claim.present?
              end

              if auto_claim.errors.present?
                raise Common::Exceptions::UnprocessableEntity.new(detail: auto_claim.errors.messages.to_s)
              end

              ClaimsApi::ClaimEstablisher.perform_async(auto_claim.id)

              present auto_claim, with: ClaimsApi::Entities::V2::DisabilityClaimSubmittedEntity, base_url: request.base_url
            end

            desc 'Submit a claim attachment.' do
              success code: 202, model: ClaimsApi::Entities::V2::DisabilityClaimSubmittedEntity
              failure [
                [401, 'Unauthorized', 'ClaimsApi::Entities::V2::ErrorsEntity'],
                [400, 'Bad Request', 'ClaimsApi::Entities::V2::ErrorsEntity']
              ]
              tags ['Forms']
              security [{ bearer_token: [] }]
            end
            params do
              requires :token, type: String
              requires :id, type: String, desc: 'Unique claim identifier.'
            end
            route_param :id do
              post :attachments do
                status 202

                raise 'NotImplemented'
              end
            end
          end
        end
      end
    end
  end
end
