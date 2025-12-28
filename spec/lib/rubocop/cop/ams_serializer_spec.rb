# frozen_string_literal: true

require 'rubocop_spec_helper'

RSpec.describe RuboCop::Cop::AmsSerializer, :config do
  it 'registers an offense when inheriting from ActiveModel::Serializer' do
    expect_offense(<<~RUBY)
      class MySerializer < ActiveModel::Serializer
                           ^^^^^^^^^^^^^^^^^^^^^^^ Use JSONAPI::Serializer instead of ActiveModel::Serializer
      end
    RUBY
  end

  it 'registers an offense when inheriting from ::ActiveModel::Serializer' do
    expect_offense(<<~RUBY)
      class MySerializer < ::ActiveModel::Serializer
                           ^^^^^^^^^^^^^^^^^^^^^^^^^ Use JSONAPI::Serializer instead of ActiveModel::Serializer
      end
    RUBY
  end

  it 'registers an offense when inheriting from ActiveModel::Serializer::CollectionSerializer' do
    expect_offense(<<~RUBY)
      class MySerializer < ActiveModel::Serializer::CollectionSerializer
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use JSONAPI::Serializer instead of ActiveModel::Serializer
      end
    RUBY
  end

  it 'does not register an offense when inheriting from JSONAPI::Serializer' do
    expect_no_offenses(<<~RUBY)
      class MySerializer
        include JSONAPI::Serializer
      end
    RUBY
  end

  it 'does not register an offense for other base classes' do
    expect_no_offenses(<<~RUBY)
      class MyClass < ApplicationRecord
      end
    RUBY
  end
end
