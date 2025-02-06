# frozen_string_literal: true

module AccreditedRepresentativePortal
  module StagingSeeds
    module Methods
      def create_claimants(count = 10)
        Array.new(count) do
          FactoryBot.create(:user_account)
        end
      end

      def create_request_with_resolution(org:, rep:, claimant:, resolution_cycle:, resolved_time:, unresolved_time:,
                                         totals:)
        if rand < 0.5
          created_at = resolved_time.next
          request = create_poa_request(org, rep, claimant, created_at)
          create_resolution(request, resolution_cycle.next)
          totals[:resolutions] += 1
        else
          create_poa_request(org, rep, claimant, unresolved_time.next)
        end

        totals[:requests] += 1
      end

      def create_poa_request(org, rep, claimant, created_at)
        request = PowerOfAttorneyRequest.new(
          claimant_id: claimant.id,
          claimant_type: 'veteran',
          power_of_attorney_holder_type: 'AccreditedOrganization',
          power_of_attorney_holder_poa_code: org.poa,
          accredited_individual_registration_number: rep.representative_id,
          created_at: created_at
        )

        form = AccreditedRepresentativePortal::PowerOfAttorneyForm.new(
          data: build_poa_form_data.to_json,
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
                      exp.save ? exp : nil
                    when :decision
                      dec = AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision.new(
                        type: AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision::Types::ACCEPTANCE,
                        creator_id: request.claimant_id
                      )
                      dec.save ? dec : nil
                    end

        return unless resolving&.persisted?

        AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution.create!(
          power_of_attorney_request: request,
          resolving: resolving,
          created_at: request.created_at + 1.day
        )
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
              first: 'Test',
              middle: nil,
              last: 'Veteran'
            },
            address: {
              address_line1: '123 Test St',
              address_line2: nil,
              city: 'Testville',
              state_code: 'TS',
              country: 'US',
              zip_code: '12345',
              zip_code_suffix: nil
            },
            ssn: '123456789',
            va_file_number: '123456789',
            date_of_birth: '1980-01-01',
            service_number: nil,
            service_branch: 'ARMY',
            phone: '1234567890',
            email: 'test@example.com'
          },
          dependent: nil
        }
      end
    end
  end
end
