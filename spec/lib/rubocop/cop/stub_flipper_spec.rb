# frozen_string_literal: true

require 'rubocop_spec_helper'

RSpec.describe RuboCop::Cop::StubFlipper, :config do
  it 'registers an offense when using Flipper.enable' do
    expect_offense(<<~RUBY)
      Flipper.enable(:feature_flag)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `allow(Flipper).to receive(:enabled?)` instead of `Flipper.enable/disable` in specs
    RUBY
  end

  it 'registers an offense when using Flipper.disable' do
    expect_offense(<<~RUBY)
      Flipper.disable(:feature_flag)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `allow(Flipper).to receive(:enabled?)` instead of `Flipper.enable/disable` in specs
    RUBY
  end

  it 'registers an offense when using Flipper.enable with additional arguments' do
    expect_offense(<<~RUBY)
      Flipper.enable(:feature_flag, user)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use `allow(Flipper).to receive(:enabled?)` instead of `Flipper.enable/disable` in specs
    RUBY
  end

  it 'does not register an offense when using allow(Flipper)' do
    expect_no_offenses(<<~RUBY)
      allow(Flipper).to receive(:enabled?).with(:feature_flag).and_return(true)
    RUBY
  end

  it 'does not register an offense for other Flipper methods' do
    expect_no_offenses(<<~RUBY)
      Flipper.enabled?(:feature_flag)
    RUBY
  end
end
