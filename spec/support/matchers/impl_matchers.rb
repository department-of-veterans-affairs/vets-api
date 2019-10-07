# frozen_string_literal: true

RSpec::Matchers.define :have_constant do |const|
  match do |owner|
    owner.const_defined?(const)
  end

  failure_message do |actual|
    "expected #{actual} to have constant #{const} defined on it"
  end
end
