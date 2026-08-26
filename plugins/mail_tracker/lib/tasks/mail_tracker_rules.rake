require 'csv'

namespace :mail_tracker do
  desc "Find invalid mail tracking rules and export to CSV"
  task export_invalid_rules: :environment do
    csv_file = Rails.root.join('log', 'invalid_mail_tracking_rules.csv')
    
    CSV.open(csv_file, 'w') do |csv|
      csv << ['Rule ID', 'User Login', 'Group ID', 'Group Name', 'Project ID', 'Project Name']
      
      MailTrackingRule.find_each do |rule|
        project = Project.find_by(id: rule.assigned_project_id)
        group = Group.find_by(id: rule.assigned_group_id)
        
        if project.nil? || group.nil?
          csv << [
            rule.id,
            rule.login_name,
            rule.assigned_group_id,
            group&.lastname,
            rule.assigned_project_id,
            project&.name
          ]
        else
          member = Member.find_by(project_id: project.id, user_id: group.id)
          if member.nil?
            csv << [
              rule.id,
              rule.login_name,
              rule.assigned_group_id,
              group.lastname,
              rule.assigned_project_id,
              project.name
            ]
          end
        end
      end
    end
    
    puts "Invalid rules exported to #{csv_file}"
  end
end
