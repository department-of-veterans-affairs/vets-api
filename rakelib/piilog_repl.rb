# frozen_string_literal: true

# run this with:  bin/rails runner rakelib/piilog_repl.rb

# see "spec/rakelib/piilog_repl/piilog_helpers_spec.rb" for more examples of using
# the PersonalInformationLogQueryBuilder

require_relative 'piilog_repl/piilog_helpers'

Q = PersonalInformationLogQueryBuilder

pry
