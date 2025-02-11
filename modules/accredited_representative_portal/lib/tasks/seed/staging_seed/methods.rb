# frozen_string_literal: true

module AccreditedRepresentativePortal
  module StagingSeeds
    RequestOptions = Struct.new(
      :org, :rep, :claimant, :resolution_cycle,
      :resolved_time, :unresolved_time, :totals,
      keyword_init: true
    )

    module RequestMethods
      def create_claimants(count = 10)
        # just grab users to be claimants
        UserAccount.limit(count).to_a
      end

      def create_request_with_resolution(options)
        if rand < 0.5
          created_at = options.resolved_time.next
          request = create_poa_request(options.org, options.rep, options.claimant, created_at)
          create_resolution(request, options.resolution_cycle.next)
          options.totals[:resolutions] += 1
        else
          create_poa_request(options.org, options.rep, options.claimant, options.unresolved_time.next)
        end

        options.totals[:requests] += 1
      end

      def create_poa_request(org, rep, claimant, created_at)
        request = PowerOfAttorneyRequest.new(
          claimant_id: claimant.id,
          claimant_type: 'veteran',
          power_of_attorney_holder_type: org ? 'AccreditedOrganization' : 'AccreditedIndividual',
          power_of_attorney_holder_poa_code: org&.poa,
          accredited_individual_registration_number: rep.representative_id,
          created_at: created_at
        )

        form = AccreditedRepresentativePortal::PowerOfAttorneyForm.new(
          data: FormMethods.build_poa_form_data.to_json,
          power_of_attorney_request: request
        )

        form.save!
        request.power_of_attorney_form = form
        request.save!

        request
      end

      def create_resolution(request, resolution_type)
        resolving = case resolution_type
                    when :expiration
                      exp = AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration.new
                      exp.save! && exp
                    when :decision
                      type = resolution_type_cycle.next
                      dec = AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.new(
                        type: type,
                        creator_id: request.claimant_id
                      )
                      dec.save! && dec
                    end
        (res = AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.new(
          power_of_attorney_request: request,
          resolving: resolving,
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
        matching_reps = Veteran::Service::Representative
                        .where('poa_codes && ARRAY[?]::varchar[]', [org.poa])
                        .limit(2)

        matching_reps.each do |rep|
          create_request_with_resolution(build_request_options(org, rep, options))
        end
      end

      def build_request_options(org, rep, options)
        RequestOptions.new(
          org: org,
          rep: rep,
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
          dependent: nil
        }
      end

      def build_authorizations
        {
          record_disclosure: true,
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
        AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyForm.destroy_all
        AccreditedRepresentativePortal::PowerOfAttorneyRequest.destroy_all
      end
    end
  end
end
