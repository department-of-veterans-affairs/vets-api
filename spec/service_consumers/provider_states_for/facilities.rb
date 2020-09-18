# frozen_string_literal: true

Pact.provider_states_for 'Facility Locator' do
  provider_state 'facilities: ccp data exists' do
    vcr_options = {
      match_requests_on: %i[path query],
      allow_playback_repeats: true
    }
    set_up do
      Flipper.enable(:facility_locator_ppms_location_query, false)
      VCR.insert_cassette('facilities/ppms/ppms', vcr_options)
    end

    tear_down do
       VCR.eject_cassette('facilities/ppms/ppms')
    end
  end
end
