# frozen_string_literal: true

require 'rubocop_spec_helper'

RSpec.describe RuboCop::Cop::Sidekiq::RequireExhaustedHook, :config do
  it 'registers an offense when sidekiq_retries_exhausted is missing' do
    expect_offense(<<~RUBY)
      class MyJob
            ^^^^^ Sidekiq jobs with retries must implement `sidekiq_retries_exhausted` hook
        include Sidekiq::Job
        sidekiq_options retry: 5
      end
    RUBY
  end

  it 'registers an offense for Sidekiq::Worker without exhausted hook' do
    expect_offense(<<~RUBY)
      class MyWorker
            ^^^^^^^^ Sidekiq jobs with retries must implement `sidekiq_retries_exhausted` hook
        include Sidekiq::Worker
        sidekiq_options retry: 10
      end
    RUBY
  end

  it 'does not register an offense when sidekiq_retries_exhausted is present' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job
        sidekiq_options retry: 5

        sidekiq_retries_exhausted do |msg, ex|
          # handle exhaustion
        end
      end
    RUBY
  end

  it 'does not register an offense when retry: 0' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job
        sidekiq_options retry: 0
      end
    RUBY
  end

  it 'does not register an offense when retry: false' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job
        sidekiq_options retry: false
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

  it 'does not register an offense when no sidekiq_options but has exhausted hook' do
    expect_no_offenses(<<~RUBY)
      class MyJob
        include Sidekiq::Job

        sidekiq_retries_exhausted do |msg, ex|
          # handle exhaustion
        end
      end
    RUBY
  end
end
