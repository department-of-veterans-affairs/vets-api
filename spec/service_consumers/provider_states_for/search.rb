# frozen_string_literal: true

Pact.provider_states_for 'Search' do
  provider_state 'multiple matching results exist' do
    set_up do
      VCR.insert_cassette('search/success_utf8')
    end

    tear_down do
      VCR.eject_cassette
    end
  end
end