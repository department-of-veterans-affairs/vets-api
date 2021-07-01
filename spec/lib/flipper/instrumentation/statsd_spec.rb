require 'rails_helper'

RSpec.describe StatsD do

  context 'Monitoring Flippers Cache hit/miss rate' do
    before do
      allow(StatsD).to receive(:increment)

      expect(StatsD).to receive(:increment).with(
        'active_support.cache_read.attempt',
        {
          tags: [
            'flipper',
            'flipper/v1/feature/testing_flipper_cache'
          ]
        }
      )
      Flipper.enable(:testing_flipper_cache, true)
    end

    context 'Cache Miss' do
      it "sends 'cache_read.active_support' notification" do
        expect(StatsD).to receive(:increment).with(
          'active_support.cache_read.miss',
          {
            tags: [
              'flipper',
              'flipper/v1/feature/testing_flipper_cache'
            ]
          }
        )

        expect do
          Flipper.enabled?(:testing_flipper_cache)
        end.to instrument('cache_read.active_support')
      end
    end

    context 'Cache Hit' do
      it "sends 'cache_read.active_support' notification" do
        Flipper.enabled?(:testing_flipper_cache)

        expect(StatsD).not_to receive(:increment).with(
          'active_support.cache_read.miss',
          {
            tags: [
              'flipper',
              'flipper/v1/feature/testing_flipper_cache'
            ]
          }
        )

        expect do
          Flipper.enabled?(:testing_flipper_cache)
        end.to instrument('cache_read.active_support')
      end
    end
  end
end