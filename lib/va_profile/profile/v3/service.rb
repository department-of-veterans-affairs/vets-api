# frozen_string_literal: true

require_relative 'bio_path_builder'
require_relative 'configuration'
require_relative 'health_benefit_bio_response'
require_relative 'military_occupation_response'
require_relative 'person_response'
require_relative 'transaction_response'

module VAProfile
  module Profile
    module V3
      # NOTE: This controller is used for discovery purposes.
      # Please contact the Authenticated Experience Profile team before using.
      class Service < Common::Client::Base
        configuration VAProfile::Profile::V3::Configuration

        OID = '2.16.840.1.113883.3.42.10001.100001.12'
        AAID = '^NI^200DOD^USDOD'

        attr_reader :user

        def initialize(user)
          @user = user
          super()
        end

        def get_health_benefit_bio
          oid = MPI::Constants::VA_ROOT_OID
          path = "#{oid}/#{ERB::Util.url_encode(icn_with_aaid)}"
          service_response = perform(:post, path, { bios: [{ bioPath: 'healthBenefit' }] })
          response = VAProfile::Profile::V3::HealthBenefitBioResponse.new(service_response)
          Sentry.set_extras(response.debug_data) unless response.ok?
          response
        end

        def get_military_info
          config.submit(path(@user.edipi), body)
        end

        def get_military_occupations
          builder = VAProfile::Profile::V3::BioPathBuilder.new(:military_occupations)
          response = submit(builder.params)
          VAProfile::Profile::V3::MilitaryOccupationResponse.new(response)
        end

        # def get_response(model)
          # Adding this for future reference. This is not used for ProfileInformation
          # This will replace get_military_occupations and get_health_benefit_bio in the future
          # Need to figure out universal bio_path solution
        #   model.response_class(perform(:post, path, { bios: [{ bioPath: model.bio_path }] }))
        #   response = model.response_class(service_response)
        #   Sentry.set_extras(response.debug_data) unless response.ok?
        #   response
        # end

        # def self.get_response(model)
        #   get_response(model)
        # end

        # def submit(params)
        #   config.submit(path(@user.edipi), params)
        # end

        # POSTs a new address to the VAProfile API
        # @param address [VAProfile::Models::Address] the address to create
        # @return [VAProfile::ContactInformation::AddressTransactionResponse] response wrapper around
        #   an transaction object
        def create_or_update_info(http_verb, type, record, response_class)
          raw_response = perform(http_verb.to_sym, type.pluralize, record.in_json)
          response = response_class.from(raw_response)
          if http_verb.to_sym == :put && type == "email"
            rescue if old_email.nil?
            transaction = response.transaction
            return if !transaction.received?
            OldEmail.create(transaction_id: transaction.id, email: old_email)
          end
          response
        rescue => e
          handle_error(e)
        end

        private

        def icn_with_aaid
          return "#{user.idme_uuid}^PN^200VIDM^USDVA" if user.idme_uuid
          return "#{user.logingov_uuid}^PN^200VLGN^USDVA" if user.logingov_uuid
          nil
        end

        def path(edipi)
          "#{OID}/#{ERB::Util.url_encode("#{edipi}#{AAID}")}"
        end

        def path
          oid = MPI::Constants::VA_ROOT_OID
          path = "#{oid}/#{ERB::Util.url_encode(icn_with_aaid)}"
        end

        def body
          {
            bios: [
              { bioPath: 'militaryPerson.adminDecisions' },
              { bioPath: 'militaryPerson.adminEpisodes' },
              { bioPath: 'militaryPerson.dentalIndicators' },
              { bioPath: 'militaryPerson.militaryOccupations', parameters: { scope: 'all' } },
              { bioPath: 'militaryPerson.militaryServiceHistory', parameters: { scope: 'all' } },
              { bioPath: 'militaryPerson.militarySummary' },
              { bioPath: 'militaryPerson.militarySummary.customerType.dodServiceSummary' },
              { bioPath: 'militaryPerson.payGradeRanks', parameters: { scope: 'highest' } },
              { bioPath: 'militaryPerson.prisonerOfWars' },
              { bioPath: 'militaryPerson.transferOfEligibility' },
              { bioPath: 'militaryPerson.retirements' },
              { bioPath: 'militaryPerson.separationPays' },
              { bioPath: 'militaryPerson.retirementPays' },
              { bioPath: 'militaryPerson.combatPays' },
              { bioPath: 'militaryPerson.unitAssignments' }
            ]
          }
        end

        def send_change_notifications(transaction_status)
          transaction = transaction_status.transaction
          # is transaction_status.changed_field a string or symbol?
          personalisaton = transaction_status.changed_field
          email_transaction = personalisaton == "email"
          if transaction.completed_success?
            transaction_id = transaction.id
            return if TransactionNotification.find(transaction_id).present?

            notify_email = email_transaction ? old_email(transaction_id) : old_email
            return if notify_email.nil?

            notify_email_job(notify_email, personalisation)

            if email_transaction
              notify_email_job(transaction_status.new_email, personalisation) if transaction_status.new_email.present?
              OldEmail.find(transaction_id).destroy
            else
              TransactionNotification.create(transaction_id:)
            end
          end
        end

        def notify_email_job(notify_email, personalisation)
          VANotifyEmailJob.perform_async(notify_email, CONTACT_INFO_CHANGE_TEMPLATE, personalisation)
        end

        def old_email(transaction_id: nil)
          return @user.va_profile_email if transaction_id.nil?
          OldEmail.find(transaction_id).try(:email)
        end

        def get_transaction_status(transaction_id, type, response_class)
          route = "#{@user.vet360_id}/#{type}/status/#{transaction_id}"
          raw_response = perform(:get, route)
          VAProfile::Stats.increment_transaction_results(raw_response)

          transaction_status = response_class.from(raw_response)
          send_change_notifications(transaction_status)

          transaction_status
        rescue => e
          handle_error(e)
        end
      end
    end
  end
end
