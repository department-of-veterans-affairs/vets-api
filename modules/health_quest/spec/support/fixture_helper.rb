# frozen_string_literal: true

def fixture_file_path(filename)
  HealthQuest::Engine.root.join("spec/fixtures/#{filename}").to_s
end

def read_fixture_file(filename)
  File.read fixture_file_path(filename)
end
