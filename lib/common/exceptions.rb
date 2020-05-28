# frozen_string_literal: true

module Common::Exceptions
end

# require each exception file
Dir["lib/common/exceptions/**/*.rb"].each { |file| require file.gsub('lib/', '') }