
module TimelogHelper
  include ApplicationHelper

  # Returns a collection of activities for a select field.  time_entry
  # is optional and will be used to check if the selected TimeEntryActivity
  # is active.
  def activity_collection_for_select_options(time_entry=nil, project=nil)
    project ||= time_entry.try(:project)
    project ||= @project
    activities = TimeEntryActivity.available_activities(project)

    collection = []
    if time_entry && time_entry.activity && !time_entry.activity.active?
      collection << ["--- #{l(:actionview_instancetag_blank_option)} ---", '']
    else
      unless activities.detect(&:is_default)
        collection << ["--- #{l(:actionview_instancetag_blank_option)} ---", '']
      end
    end
    activities.each {|a| collection << [a.name, a.id]}
    collection
  end

  def user_collection_for_select_options(time_entry)
    collection = time_entry.assignable_users
    if time_entry.user && !collection.include?(time_entry.user)
      collection << time_entry.user
    end
    principals_options_for_select(collection, time_entry.user_id.to_s)
  end

  def default_activity(time_entry)
    if @project
      time_entry.activity_id
    else
      TimeEntryActivity.default_activity_id(User.current, time_entry.project)
    end
  end

  def select_hours(data, criteria, value)
    if value.to_s.empty?
      data.select {|row| row[criteria].blank?}
    else
      data.select {|row| row[criteria].to_s == value.to_s}
    end
  end

  def sum_hours(data)
    sum = 0
    data.each do |row|
      sum += row['hours'].to_f
    end
    sum
  end

  def format_criteria_value(criteria_options, value, html=true)
    if value.blank?
      "[#{l(:label_none)}]"
    elsif k = criteria_options[:klass]
      obj = k.find_by_id(value.to_i)
      if obj.is_a?(Issue)
        if obj.visible?
          html ? link_to_issue(obj) : "#{obj.tracker} ##{obj.id}: #{obj.subject}"
        else
          "##{obj.id}"
        end
      else
        format_object(obj, html)
      end
    elsif cf = criteria_options[:custom_field]
      format_value(value, cf)
    else
      value.to_s
    end
  end

  def report_to_csv(report)
    Redmine::Export::CSV.generate(:encoding => params[:encoding]) do |csv|
      # Column headers
      headers =
        report.criteria.collect do |criteria|
          l_or_humanize(report.available_criteria[criteria][:label])
        end
      headers += report.periods
      headers << l(:label_total_time)
      csv << headers
      # Content
      report_criteria_to_csv(csv, report.available_criteria, report.columns,
                             report.criteria, report.periods, report.hours)
      # Total row
      str_total = l(:label_total_time)
      row = [str_total] + [''] * (report.criteria.size - 1)
      total = 0
      report.periods.each do |period|
        sum = sum_hours(select_hours(report.hours, report.columns, period.to_s))
        total += sum
        row << (sum > 0 ? sum : '')
      end
      row << total
      csv << row
    end
  end

  def report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours, level=0)
    hours.collect {|h| h[criteria[level]].to_s}.uniq.each do |value|
      hours_for_value = select_hours(hours, criteria[level], value)
      next if hours_for_value.empty?

      row = [''] * level
      row << format_criteria_value(available_criteria[criteria[level]], value, false).to_s
      row += [''] * (criteria.length - level - 1)
      total = 0
      periods.each do |period|
        sum = sum_hours(select_hours(hours_for_value, columns, period.to_s))
        total += sum
        row << (sum > 0 ? sum : '')
      end
      row << total
      csv << row
      if criteria.length > level + 1
        report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours_for_value, level + 1)
      end
    end
  end

  def cancel_button_tag_for_time_entry(project)
    fallback_path = project ? project_time_entries_path(project) : time_entries_path
    cancel_button_tag(fallback_path)
  end

  def render_timelog_breadcrumb
    links = []
    links << link_to(l(:label_project_all), {:project_id => nil, :issue_id => nil})
    links << link_to(h(@project), {:project_id => @project, :issue_id => nil}) if @project
    if @issue
      if @issue.visible?
        links << link_to_issue(@issue, :subject => false)
      else
        links << "##{@issue.id}"
      end
    end
    breadcrumb links
  end

  # Returns a collection of activities for a select field.  time_entry
  # is optional and will be used to check if the selected TimeEntryActivity
  # is active.
  def activity_collection_for_select_options(time_entry=nil, project=nil)
    project ||= time_entry.try(:project)
    project ||= @project
    if project.nil?
      activities = TimeEntryActivity.shared.active
    else
      activities = project.activities
    end

    collection = []
    if time_entry && time_entry.activity && !time_entry.activity.active?
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ]
    else
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ] unless activities.detect(&:is_default)
    end
    activities.each { |a| collection << [a.name, a.id] }
    collection
  end

  def prior_friday(date)
    days_to_subtract = (date.cwday + 2) % 7
    days_to_subtract = 7 if days_to_subtract.zero?
    date - days_to_subtract
  end

  def minimum_time(current_user)
    return nil unless Setting.allow_logging_time.eql?('1') || !current_user.admin

    if Time.current.monday?
      if Time.current.hour.to_i >= Setting.allow_logging_time_till.to_time.hour.to_i
        Date.current.strftime('%Y-%m-%d')
      else
        prior_friday(Date.current)
      end
    elsif Time.current.hour.to_i >= Setting.allow_logging_time_till.to_time.hour.to_i
      Date.current.strftime('%Y-%m-%d')
    else
      Date.yesterday.strftime('%Y-%m-%d')
    end
  end
end