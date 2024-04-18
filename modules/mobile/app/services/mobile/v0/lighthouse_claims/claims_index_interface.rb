# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'lighthouse/benefits_claims/service'
require_relative '../claims/proxy'

module Mobile
  module V0
    module LighthouseClaims
      class ClaimsIndexInterface
        CLAIMS_NOT_AUTHORIZED_MESSAGE = 'Forbidden: User is not authorized for claims'
        APPEALS_NOT_AUTHORIZED_MESSAGE = 'Forbidden: User is not authorized for appeals'
        def initialize(user)
          @current_user = user
        end

        def get_accessible_claims_appeals(use_cache)
          data, errors = if claims_access? && appeals_access?
                           get_claims_and_appeals(use_cache)
                         elsif claims_access?
                           get_claims(use_cache)
                         elsif appeals_access?
                           get_appeals(use_cache)
                         else
                           raise Pundit::NotAuthorizedError
                         end

          try_cache(data, errors)

          [data, errors]
        end

        private

        def try_cache(data, errors)
          Mobile::V0::ClaimOverview.set_cached(@current_user, data) unless non_authorization_errors?(errors)
        end

        def get_claims_and_appeals(use_cache)
          full_list = []
          errors = []
          data = nil

          data = Mobile::V0::ClaimOverview.get_cached(@current_user) if use_cache

          unless data
            claims, appeals = Parallel.map([service.get_all_claims, service.get_all_appeals], in_threads: 2, &:call)
            claims[:errors].nil? ? full_list.push(*claims[:list]) : errors.push(claims[:errors])
            appeals[:errors].nil? ? full_list.push(*appeals[:list]) : errors.push(appeals[:errors])
            data = claims_adapter.parse(full_list)
          end

          errors = errors.map { |err| simplify_error(err) }

          [data, errors]
        end

        # this is being done to fix a front end bug in which error details consisting of an array of objects causes
        # the mobile app to crash
        def simplify_error(err)
          details = err[:error_details]
          return err if details.is_a?(String)

          raise StandardError('Invalid format') unless details.is_a?(Array)

          messages = details.map do |ed|
            message = ed['details'] || ed['text']
            raise StandardError('Invalid format') unless message

            message
          end
          err[:error_details] = messages.join('; ')
          err
        rescue => e
          Rails.logger.error('explain error')
          err
        end

        def get_claims(use_cache)
          errors = []
          data = nil

          data = Mobile::V0::ClaimOverview.get_cached(@current_user) if use_cache
          unless data
            claims = service.get_all_claims.call
            errors.push(claims[:errors]) unless claims[:errors].nil?
            data = claims[:errors].nil? ? claims_adapter.parse(claims[:list]) : []
          end
          errors.push({ service: 'appeals', error_details: APPEALS_NOT_AUTHORIZED_MESSAGE })

          [data, errors]
        end

        def get_appeals(use_cache)
          errors = []
          data = nil

          data = Mobile::V0::ClaimOverview.get_cached(@current_user) if use_cache

          unless data
            appeals = service.get_all_appeals.call
            errors.push(appeals[:errors]) unless appeals[:errors].nil?
            data = appeals[:errors].nil? ? claims_adapter.parse(appeals[:list]) : []
          end

          errors.push({ service: 'claims', error_details: CLAIMS_NOT_AUTHORIZED_MESSAGE })

          [data, errors]
        end

        def non_authorization_errors?(service_errors)
          return false unless service_errors

          authorization_errors = [CLAIMS_NOT_AUTHORIZED_MESSAGE, APPEALS_NOT_AUTHORIZED_MESSAGE]
          !service_errors.all? { |error| authorization_errors.include?(error[:error_details]) }
        end

        def service
          claim_status_lighthouse? ? lighthouse_claims_proxy : evss_claims_proxy
        end

        def claims_access?
          if claim_status_lighthouse?
            @current_user.authorize(:lighthouse,
                                    :access?)
          else
            @current_user.authorize(:evss, :access?)
          end
        end

        def appeals_access?
          @current_user.authorize(:appeals, :access?)
        end

        def claim_status_lighthouse?
          Flipper.enabled?(:mobile_lighthouse_claims, @current_user)
        end

        def lighthouse_claims_proxy
          Mobile::V0::LighthouseClaims::Proxy.new(@current_user)
        end

        def claims_adapter
          if claim_status_lighthouse?
            Mobile::V0::Adapters::LighthouseClaimsOverview.new
          else
            Mobile::V0::Adapters::ClaimsOverview.new
          end
        end

        def evss_claims_proxy
          @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
        end
      end
    end
  end
end
