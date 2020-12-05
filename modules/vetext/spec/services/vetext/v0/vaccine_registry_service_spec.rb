# frozen_string_literal: true

require 'rails_helper'

describe Vetext::V0::VaccineRegistryService do
  subject { described_class.new }

  let(:user) { build(:user, :mhv) }

  let(:vaccine_registry) { build(:vaccine_registry, :auth, user: user) }

  describe '#put_vaccine_registry with user' do
    it 'creates a new vaccine registry' do
      VCR.use_cassette('vetext/put_vaccine_registry_with_user', record: :new_episodes) do
        response = subject.put_vaccine_registry(vaccine_registry.attributes)
      end
    end
  end
end
