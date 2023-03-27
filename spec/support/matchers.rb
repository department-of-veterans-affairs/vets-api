# frozen_string_literal: true

Dir[File.join(__dir__, 'matchers', '*.rb')].each { |file| require file }
