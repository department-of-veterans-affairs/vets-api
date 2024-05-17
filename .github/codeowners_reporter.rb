require 'json'

def report_codeowners_by_owner(file_path)
  reported_codeowners = {}

  File.foreach(file_path) do |line|
    next if line.strip.empty? || line.strip.start_with?("#") # Skip empty lines and comments

    path, *owners = line.split(/\s+/)
    owners = owners.map(&:strip).sort.join(" ")

    reported_codeowners[owners] ||= []
    reported_codeowners[owners] << path
  end

  reported_codeowners
end

codeowners_path = ".github/CODEOWNERS"
reported_codeowners = report_codeowners_by_owner(codeowners_path)

File.open(".github/codeowners_report.json", "w") do |file|
  file.write(JSON.pretty_generate(reported_codeowners))
end
