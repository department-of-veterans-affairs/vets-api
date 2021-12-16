# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::BaseService do
  let(:evss_user) { FactoryBot.create(:evss_user, :loa3) }
  let(:user) { FactoryBot.create(:user, :loa3, icn: '12345', common_name: 'thisuserhasareallylongemailaddress@va.gov') }

  describe '#initialize_service' do
    context 'with an external key that is less than character limit' do
      it 'instantiates BGS service succesfully' do
        service = described_class.new(evss_user).send(:initialize_service)

        expect(service.class).to eq(BGS::Services)
        config = service.instance_variable_get(:@config)

        expect(config[:external_uid]).to eq('123498767V234859')
        expect(config[:external_key]).to eq('abraham.lincoln@vets.gov')
      end
    end

    context 'with an external key that is longer than character limit' do
      it 'instantiates BGS service with no errors' do
        service = described_class.new(user).send(:initialize_service)

        expect(service.class).to eq(BGS::Services)
        config = service.instance_variable_get(:@config)

        expect(config[:external_uid]).to eq('12345')
        expect(config[:external_key]).to eq('thisuserhasareallylongemailaddress@va.g')
      end
    end
  end
end
