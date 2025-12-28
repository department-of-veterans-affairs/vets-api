# frozen_string_literal: true

require 'rubocop_spec_helper'

RSpec.describe RuboCop::Cop::SkipAuthenticity, :config do
  it 'registers an offense when using skip_before_action :verify_authenticity_token' do
    expect_offense(<<~RUBY)
      class MyController < ApplicationController
        skip_before_action :verify_authenticity_token
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not skip authenticity token verification. This exposes the application to CSRF attacks.
      end
    RUBY
  end

  it 'registers an offense with additional options' do
    expect_offense(<<~RUBY)
      class MyController < ApplicationController
        skip_before_action :verify_authenticity_token, only: [:create]
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not skip authenticity token verification. This exposes the application to CSRF attacks.
      end
    RUBY
  end

  it 'does not register an offense for other skip_before_action calls' do
    expect_no_offenses(<<~RUBY)
      class MyController < ApplicationController
        skip_before_action :authenticate_user!
      end
    RUBY
  end

  it 'does not register an offense for before_action' do
    expect_no_offenses(<<~RUBY)
      class MyController < ApplicationController
        before_action :verify_authenticity_token
      end
    RUBY
  end
end
