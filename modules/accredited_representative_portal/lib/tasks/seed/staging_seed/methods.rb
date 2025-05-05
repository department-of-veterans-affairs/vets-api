# frozen_string_literal: true

module AccreditedRepresentativePortal
  module StagingSeeds
    RequestOptions = Struct.new(
      :org, :rep, :claimant, :resolution_cycle,
      :resolved_time, :unresolved_time, :totals, :email_counter,
      keyword_init: true
    )

    module RequestMethods
      def create_claimants(count = 10)
        # just grab users to be claimants
        UserAccount.limit(count).to_a
      end

      def create_request_with_resolution(options, i)
        if i.even?
          created_at = options.resolved_time.next
          request = create_poa_request(options.org, options.rep, options.claimant, created_at)
          create_resolution(request, options.resolution_cycle.next)
          options.totals[:resolutions] += 1
        else
          create_poa_request(options.org, options.rep, options.claimant, options.unresolved_time.next, i.even?)
        end

        options.totals[:requests] += 1
      end

      # rubocop:disable Metrics/MethodLength
      def create_poa_request(org, rep, claimant, created_at, dependent_toggle)
        request = PowerOfAttorneyRequest.new(
          claimant_id: claimant.id,
          claimant_type: dependent_toggle ? 'dependent' : 'veteran',
          power_of_attorney_holder_type: org ? 'veteran_service_organization' : 'individual_representative',
          power_of_attorney_holder_poa_code: org&.poa,
          accredited_individual_registration_number: rep.representative_id,
          created_at:
        )

        form_data = {
          authorizations: FormMethods.build_authorizations,
          veteran: FormMethods.build_veteran_info,
          dependent: dependent_toggle ? FormMethods.build_dependent_info : nil
        }

        form = AccreditedRepresentativePortal::PowerOfAttorneyForm.new(
          power_of_attorney_request: request,
          data: form_data.deep_transform_keys! { |key| key.to_s.camelize(:lower) }.to_json
        )

        form.save!
        request.power_of_attorney_form = form
        request.save!

        request
      end
      # rubocop:enable Metrics/MethodLength

      def create_resolution(request, resolution_type)
        resolving = case resolution_type
                    when :expiration
                      exp = AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration.new
                      exp.save! && exp
                    when :decision
                      type = resolution_type_cycle.next
                      dec = AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.new(
                        type:,
                        creator_id: request.claimant_id
                      )
                      dec.save! && dec
                    end
        (res = AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.new(
          power_of_attorney_request: request,
          resolving:,
          created_at: request.created_at + 1.day
        )).save! && res
      end

      private

      def resolution_type_cycle
        [
          AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE,
          AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::DECLINATION
        ].cycle
      end
    end

    module OrganizationMethods
      def fetch_organizations
        {
          ct: Veteran::Service::Organization.find_by(poa: '008'),
          digital: Veteran::Service::Organization
            .where(can_accept_digital_poa_requests: true)
            .where.not(poa: '008')
            .limit(2),
          non_digital: Veteran::Service::Organization
            .where(can_accept_digital_poa_requests: false)
            .limit(2)
        }
      end

      def process_organizations(orgs, options)
        process_matched_orgs(orgs, options)
      end

      private

      def process_matched_orgs(orgs, options)
        [orgs[:ct], *orgs[:digital], *orgs[:non_digital]].each do |org|
          process_org_reps(org, options)
        end
      end

      def process_org_reps(org, options)
        matching_reps = if org.poa == '008'
                          # Get all CT reps without limit
                          Veteran::Service::Representative
                            .where('poa_codes && ARRAY[?]::varchar[]', [org.poa])
                        else
                          # limit for other orgs
                          Veteran::Service::Representative
                            .where('poa_codes && ARRAY[?]::varchar[]', [org.poa])
                            .limit(2)
                        end

        matching_reps.each do |rep|
          create_user_account_if_needed(rep, options)
          create_requests_for_rep(org, rep, options)
        end
      end

      def create_user_account_if_needed(rep, options)
        return if AccreditedRepresentativePortal::UserAccountAccreditedIndividual
                  .exists?(accredited_individual_registration_number: rep.representative_id)

        AccreditedRepresentativePortal::UserAccountAccreditedIndividual.create!(
          accredited_individual_registration_number: rep.representative_id,
          power_of_attorney_holder_type: 'veteran_service_organization',
          user_account_email: "vets.gov.user+#{options[:email_counter]}@gmail.com"
        )
        options[:totals][:user_accounts] += 1
        options[:email_counter] += 1
      end

      def create_requests_for_rep(org, rep, options)
        5.times do |i|
          if i.even?
            create_poa_request(org, rep, options[:claimant_cycle].next, options[:unresolved_time].next, i.even?)
            options[:totals][:requests] += 1
          else
            request = create_poa_request(org, rep, options[:claimant_cycle].next, options[:resolved_time].next, i.even?)
            create_resolution(request, :decision)
            options[:totals][:requests] += 1
            options[:totals][:resolutions] += 1
          end
        end
      end

      def build_request_options(org, rep, options)
        RequestOptions.new(
          org:,
          rep:,
          claimant: options[:claimant_cycle].next,
          resolution_cycle: options[:resolution_cycle],
          resolved_time: options[:resolved_time],
          unresolved_time: options[:unresolved_time],
          totals: options[:totals]
        )
      end
    end

    module FormMethods
      module_function

      def build_poa_form_data
        {
          authorizations: build_authorizations,
          veteran: build_veteran_info,
          dependent: build_dependent_info
        }
      end

      def build_dependent_info
        {
          name: build_name,
          address: build_address,
          date_of_birth: '1980-01-01',
          phone: '1234567890',
          email: 'test@example.com',
          relationship: 'Child'
        }
      end

      def build_authorizations
        {
          record_disclosure_limitations: [],
          address_change: false
        }
      end

      def build_veteran_info
        {
          name: build_name,
          address: build_address,
          ssn: '123456789',
          va_file_number: '123456789',
          date_of_birth: '1980-01-01',
          service_number: nil,
          service_branch: 'ARMY',
          phone: '1234567890',
          email: 'test@example.com'
        }
      end

      def build_name
        {
          first: 'Test',
          middle: nil,
          last: 'Veteran'
        }
      end

      def build_address
        {
          address_line1: '123 Test St',
          address_line2: nil,
          city: 'Testville',
          state_code: 'TS',
          country: 'US',
          zip_code: '12345',
          zip_code_suffix: nil
        }
      end
    end

    module Methods
      include RequestMethods
      include OrganizationMethods

      def cleanup_existing_data
        AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequestWithdrawal.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyForm.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequest.destroy_all
        AccreditedRepresentativePortal::UserAccountAccreditedIndividual.destroy_all
      end
    end
  end
end
