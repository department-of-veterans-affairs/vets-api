# frozen_string_literal: true
module EVSS
  module ReferenceData
    class Service < EVSS::Service
      configuration EVSS::ReferenceData::Configuration

      def get_countries
        with_monitoring do
          raw_response = perform(:get, 'countries')
          if raw_response.status == 200
            return response&.body.dig('countries')
          else
            # bad! TODO: implement
            puts 'Bill wuz here'
          end
        end
      end

      def get_disabilities
        raw_response = perform(:get, 'disabilities')
      end

      def get_intake_sites
        raw_response = perform(:get, 'intakesites')
      end

      def get_states
        raw_response = perform(:get, 'states')
      end

      def get_treatment_centers
        # TODO: recommend this be a GET not POST
        raw_response = perform(:post, 'treatmentcenters')
      end
    end
  end
end
