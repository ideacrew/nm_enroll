require File.join(Rails.root, "app", "data_migrations", "update_census_employee_id")
# This rake task is to update the person relationship kind
# RAILS_ENV=production bundle exec rake migrations:update_census_employee_id employee_role_id='5ba26cd3e59c4a47590000a6' input_id='5ba26cd3e59c4a47590000a6' (census_employee_id=input_id)
namespace :migrations do
  desc "Changing census employee id for employee record"
  UpdateCensusEmployeeId.define_task :update_census_employee_id => :environment
end
