# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'vets/shared_logging'
Sidekiq::Testing.fake!

RSpec.describe Organizations::UpdateNames, type: :job do
  include Vets::SharedLogging

  describe '#perform' do
    let(:organization_double) { instance_double(Veteran::Service::Organization) }

    before do
      allow(Organizations::Names).to receive(:all).and_return([{ poa: '80', name: 'Updated Name' }])
    end

    it 'updates the organization names where records exist' do
      allow(Veteran::Service::Organization).to receive(:find_by).with(poa: '80').and_return(organization_double)
      expect(organization_double).to receive(:update).with(name: 'Updated Name')

      described_class.new.perform
    end

    it 'does not attempt to update if no matching record found' do
      allow(Veteran::Service::Organization).to receive(:find_by).with(poa: '80').and_return(nil)
      expect(Veteran::Service::Organization).not_to receive(:update)

      described_class.new.perform
    end

    it 'logs an error to Sentry if an exception is raised' do
      allow(Organizations::Names).to receive(:all).and_return([{ poa: '80', name: 'Updated Name' }])
      allow(Veteran::Service::Organization).to receive(:find_by).with(poa: '80').and_raise(StandardError,
                                                                                           'Unexpected error')
      expect_any_instance_of(Vets::SharedLogging).to receive(:log_message_to_sentry).with(
        "Error updating organization name for POA in Organizations::UpdateNames: Unexpected error. POA: '80', Org Name: 'Updated Name'." # rubocop:disable Layout/LineLength
      )
      # expect_any_instance_of(Vets::SharedLogging).to receive(:log_message_to_rails).with(
      #   "Error updating organization name for POA in Organizations::UpdateNames: Unexpected error. POA: '80', Org Name: 'Updated Name'." # rubocop:disable Layout/LineLength
      # )

      described_class.new.perform
    end
  end
end
