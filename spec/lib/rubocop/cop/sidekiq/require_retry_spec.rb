# frozen_string_literal: true

require 'rubocop_spec_helper'

RSpec.describe RuboCop::Cop::Sidekiq::RequireRetry, :config do
  it 'registers an offense when sidekiq_options lacks retry' do
    expect_offense(<<~RUBY)
      class MyJob
            ^^^^^ Sidekiq jobs must explicitly specify `retry` in sidekiq_options
        include Sidekiq::Job
        sidekiq_options queue: 'default'
      end
    RUBY
  end

  it 'registers an offense when no sidekiq_options is present' do
    expect_offense(<<~RUBY)
      class MyJob
            ^^^^^ Sidekiq jobs must explicitly specify `retry` in sidekiq_options
        include Sidekiq::Job
      end
    RUBY
  end

  it 'registers an offense for Sidekiq::Worker' do
    expect_offense(<<~RUBY)
      class MyWorker
            ^^^^^^^^ Sidekiq jobs must explicitly specify `retry` in sidekiq_options
        include Sidekiq::Worker
      end
    RUBY
  end

  it 'does not register an offense when retry is specified' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job
        sidekiq_options retry: 5
      end
    RUBY
  end

  it 'does not register an offense when retry: 0 is specified' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job
        sidekiq_options retry: 0
      end
    RUBY
  end

  it 'does not register an offense when retry: false is specified' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job
        sidekiq_options retry: false
      end
    RUBY
  end

  it 'does not register an offense when retry is specified with other options' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job
        sidekiq_options queue: 'critical', retry: 10
      end
    RUBY
  end

  it 'does not register an offense for non-Sidekiq classes' do
    expect_no_offenses(<<~RUBY)
      class MyClass
        include SomeOtherModule
      end
    RUBY
  end
end
