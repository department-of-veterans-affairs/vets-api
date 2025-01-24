# frozen_string_literal: true

class CodeownersParser
  def perform(team_name)
    parsed_codeowners = File.read('.github/CODEOWNERS').split("\n").map do |line|
      next if line.start_with?('#')
      next unless line.include?(team_name)

      line.split.first
    end
    parsed_codeowners.compact
  end
end
