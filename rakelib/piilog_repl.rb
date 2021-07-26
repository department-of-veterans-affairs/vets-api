# frozen_string_literal: true

# run this by starting a rails console and running: require_relative 'rakelib/piilog_repl

# see "spec/rakelib/piilog_repl/piilog_helpers_spec.rb" for more examples of using
# the PersonalInformationLogQueryBuilder

require_relative 'piilog_repl/piilog_helpers'

Q = PersonalInformationLogQueryBuilder
