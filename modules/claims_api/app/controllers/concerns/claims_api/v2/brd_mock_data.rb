# frozen_string_literal: true

module ClaimsApi
  module V2
    # Module for mocking BRD (Benefits Reference Data) service responses during local development
    # Enable mocking by setting: export MOCK_BRD_COUNTRIES=true
    module BrdMockData
      extend ActiveSupport::Concern

      included do
        # Check if BRD mocking is enabled
        def brd_mocking_enabled?
          ENV['MOCK_BRD_COUNTRIES'] == 'true'
        end

        # Fetch countries with optional mocking
        def fetch_countries_list
          if brd_mocking_enabled?
            Rails.logger.info('Using mock countries for BRD validation (MOCK_BRD_COUNTRIES=true)')
            mock_countries
          else
            valid_countries
          end
        end

        # Fetch service branches with optional mocking
        def fetch_service_branches_list
          if brd_mocking_enabled?
            Rails.logger.info('Using mock service branches for BRD validation (MOCK_BRD_COUNTRIES=true)')
            mock_service_branches
          else
            brd_service_branch_names
          end
        end

        # Fetch disabilities with optional mocking
        def fetch_disabilities_list
          if brd_mocking_enabled?
            Rails.logger.info('Using mock disabilities for BRD validation (MOCK_BRD_COUNTRIES=true)')
            mock_disabilities
          else
            brd_disabilities
          end
        end

        # Fetch classification IDs with optional mocking
        def fetch_classification_ids
          if brd_mocking_enabled?
            mock_classification_ids
          else
            brd_classification_ids
          end
        end

        private

        # Mock data for countries
        def mock_countries
          %w[USA CAN MEX GBR FRA DEU JPN AUS]
        end

        # Mock data for service branches
        def mock_service_branches
          [
            'Air Force',
            'Air Force Reserves',
            'Army',
            'Army Reserves',
            'Coast Guard',
            'Coast Guard Reserves',
            'Marine Corps',
            'Marine Corps Reserves',
            'Navy',
            'Navy Reserves',
            'Space Force',
            'National Guard',
            'Public Health Service'
          ]
        end

        # Mock data for disabilities
        def mock_disabilities
          [
            { id: 1000, name: 'Hearing Loss', endDateTime: nil },
            { id: 2000, name: 'Tinnitus', endDateTime: nil },
            { id: 3000, name: 'PTSD', endDateTime: nil },
            { id: 4000, name: 'Back Pain', endDateTime: nil },
            { id: 5000, name: 'Knee Pain', endDateTime: nil },
            { id: 6000, name: 'Sleep Apnea', endDateTime: nil },
            { id: 7000, name: 'Depression', endDateTime: nil },
            { id: 8000, name: 'Anxiety', endDateTime: nil }
          ]
        end

        # Mock classification IDs
        def mock_classification_ids
          [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000]
        end
      end
    end
  end
end
