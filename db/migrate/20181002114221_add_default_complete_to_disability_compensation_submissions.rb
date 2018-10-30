class AddDefaultCompleteToDisabilityCompensationSubmissions < ActiveRecord::Migration
	def change
		change_column_default :disability_compensation_submissions, :complete, false
	end
end
