class BackportDefaultVettecToEducationBenefitsSubmissions < ActiveRecord::Migration
  def change
    EducationBenefitsSubmission.select(:id).find_in_batches.with_index do |records, index|
      puts "Processing batch #{index + 1}\r"
      EducationBenefitsSubmission.where(id: records).update_all(vettec: false)
    end
  end
end
