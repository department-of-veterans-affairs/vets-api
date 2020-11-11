# frozen_string_literal: true

Pact.provider_states_for 'VA Profile' do
  provider_state 'at least one entry in the service history exists' do
    set_up do
      build_user_and_stub_session
      VCR.insert_cassette('emis/get_military_service_episodes/valid')
    end

    tear_down do
      VCR.eject_cassette
    end
  end

  provider_state 'there are no service history records' do
    set_up do
      build_user_and_stub_session
      stub_mpi(
        FactoryBot.build(
          :mvi_profile,
          edipi: '1005079124'
        )
      )
      VCR.insert_cassette('emis/get_military_service_episodes/empty')
    end

    tear_down do
      VCR.eject_cassette
    end
  end

  provider_state 'not a Veteran' do
    set_up do
      build_user_and_stub_session(FactoryBot.build(:unauthorized_evss_user))
    end

    tear_down do
    end
  end
end
