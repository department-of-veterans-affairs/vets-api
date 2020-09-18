# frozen_string_literal: true

# ./modules/health_quest/spec/services/pgd_service_spec.rb

require 'rails_helper'
require_relative '../support/health_fixture_helper'

describe HealthQuest::PGDService do
  let(:user) { build(:user, :health_quest) }
  let(:subject) { described_class.new(user) }
  let(:expected_data) { OpenStruct.new({ id: '333', text: 'this is the questionnaire', type: :questionnaire }) }
  let(:dummy_response) { double('fake_response', body: { data: expected_data }) }

  before do
    allow_any_instance_of(HealthQuest::UserService).to receive(:session).and_return(:dummy_session)
    allow_any_instance_of(HealthQuest::SessionService).to receive(:perform).and_return(dummy_response)
  end

  describe '#get_pgd_resource' do
    it 'gets a PGD resource' do
      expect(subject.get_pgd_resource(:questionnaire)[:data]).to eq(dummy_response.body[:data])
    end
  end

  describe '#get_pgd_base_url' do
    it 'gets a url' do
      # ubocop:disable Layout/LineLength
      expect(subject.send(:get_pgd_base_url, 'questionnaire')).to eq("/questionnaire/v1/patients/#{user.icn}")
      # ubocop:enable Layout/LineLength
    end
  end

  describe '#page_params' do
    it 'has pagination' do
      expect(subject.send(:page_params, { per_page: 20, page: 2 })).to eq({ pageSize: 20, page: 2 })
    end

    it 'handles negative page size' do
      expect(subject.send(:page_params, { per_page: -20, page: 2 })).to eq({ pageSize: -20 })
    end
  end
end
