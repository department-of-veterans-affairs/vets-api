module AccreditedRepresentativePortal
  module StagingSeeds
    class << self
      def run
        ActiveRecord::Base.transaction do
          total_created = { requests: 0, resolutions: 0 }

          claimants = create_claimants
          claimant_cycle = claimants.cycle

          resolution_cycle = RESOLUTION_HISTORY_CYCLE
          resolved_time = RESOLVED_TIME_TRAVELER
          unresolved_time = UNRESOLVED_TIME_TRAVELER

          Veteran::Service::Representative.find_each do |rep|
            matching_orgs = Veteran::Service::Organization.where(poa: rep.poa_codes)
            next if matching_orgs.empty?

            matching_orgs.each do |org|
              create_request_with_resolution(
                org: org,
                rep: rep,
                claimant: claimant_cycle.next,
                resolution_cycle: resolution_cycle,
                resolved_time: resolved_time,
                unresolved_time: unresolved_time,
                totals: total_created
              )
            end
          end

          log_results(total_created)
        end
      end

      private

      RESOLUTION_HISTORY_CYCLE = %i[expiration decision].cycle

      RESOLVED_TIME_TRAVELER =
        Enumerator.new do |yielder|
          time = 30.days.ago
          loop do
            yielder << time
            time += 6.hours
          end
        end

      UNRESOLVED_TIME_TRAVELER =
        Enumerator.new do |yielder|
          time = 10.days.ago
          loop do
            yielder << time
            time += 6.hours
          end
        end

      def create_claimants(count = 10)
        Array.new(count) do
          FactoryBot.create(:user_account)
        end
      end

      def create_request_with_resolution(org:, rep:, claimant:, resolution_cycle:, resolved_time:, unresolved_time:, totals:)
        if rand < 0.5
          created_at = resolved_time.next
          request = create_poa_request(org, rep, claimant, created_at)
          create_resolution(request, resolution_cycle.next)
          totals[:resolutions] += 1
        else
          request = create_poa_request(org, rep, claimant, unresolved_time.next)
        end
        
        totals[:requests] += 1
      end

      def create_poa_request(org, rep, claimant, created_at)
        # Create request without form first
        request = PowerOfAttorneyRequest.new(
          claimant_id: claimant.id,
          claimant_type: 'veteran',
          power_of_attorney_holder_type: 'AccreditedOrganization',
          power_of_attorney_holder_poa_code: org.poa,
          accredited_individual_registration_number: rep.representative_id,
          created_at: created_at
        )

        # Create form with request
        form = AccreditedRepresentativePortal::PowerOfAttorneyForm.new(
          data: build_poa_form_data.to_json,
          power_of_attorney_request: request
        )

        # Save both
        form.save!
        request.power_of_attorney_form = form
        request.save!
        
        request
      end

      def create_resolution(request, resolution_type)
        resolving = case resolution_type
        when :expiration
          exp = AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration.new
          if exp.save
            exp
          end
        when :decision
          dec = AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.new(
            type: AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE,
            creator_id: request.claimant_id
          )
          if dec.save
            dec
          end
        else
          raise "Unknown resolution type: #{resolution_type}"
        end
      
        if resolving&.persisted?
          resolution = AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.create!(
            power_of_attorney_request: request,
            resolving: resolving,
            created_at: request.created_at + 1.day
          )
          resolution
        else
          raise "Failed to create resolving record"
        end
      end

      def build_poa_form_data
        {
          authorizations: {
            record_disclosure: true,
            record_disclosure_limitations: [],
            address_change: false
          },
          veteran: {
            name: {
              first: "Test",
              middle: nil,
              last: "Veteran"
            },
            address: {
              address_line1: "123 Test St",
              address_line2: nil,
              city: "Testville",
              state_code: "TS",
              country: "US",
              zip_code: "12345",
              zip_code_suffix: nil
            },
            ssn: "123456789",
            va_file_number: "123456789",
            date_of_birth: "1980-01-01",
            service_number: nil,
            service_branch: "ARMY",
            phone: "1234567890",
            email: "test@example.com"
          },
          dependent: nil
        }
      end

      def log_results(totals)
        Rails.logger.info(
          "Seeding complete: Created #{totals[:requests]} requests " \
          "and #{totals[:resolutions]} resolutions"
        )
      end
    end
  end
end
