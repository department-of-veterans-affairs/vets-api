# frozen_string_literal: true
Dir[File.join(Rails.root, 'lib', 'core_extensions', '*.rb')].each { |file| require file }
