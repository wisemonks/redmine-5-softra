class MailTrackingRulesController < ApplicationController
  unloadable
  def index

  end

  def show
    # @rules = MailTrackingRule.all
    # @host = MailSource.last
  end


  def assignable_groups
    project = Project.find_by(id: params[:project_id])
    groups = project ? project.assignable_users.where(type: 'Group').to_a.map { |g| [g.lastname, g.id] } : []
    render :json => groups
  end

  def destroy
    rule = MailTrackingRule.find(params[:id]) if params[:id].present?
    rule.destroy!
    # render :nothing => true, :status => 200, :content_type => 'text/html'
    render :json => {id: params[:id]}
  end


  def create
    declared_params = mail_tracking_rule_params
    rule = MailTrackingRule.new(declared_params.merge(login_name: params[:user][:id]))
    ensure_group_membership(declared_params[:assigned_project_id], declared_params[:assigned_group_id], params.dig(:mail_tracking_rule, :pending_role_id))
    unless rule.save
      session[:mail_tracking_rule_error] = { 'id' => 'new', 'values' => declared_params.to_h }
    end
    redirect_to edit_user_url(id: params[:user][:id])
  end

  def update
    declared_params = mail_tracking_rule_params
    if params[:id].present?
      rule = MailTrackingRule.find(params[:id])
      ensure_group_membership(declared_params[:assigned_project_id], declared_params[:assigned_group_id], params.dig(:mail_tracking_rule, :pending_role_id))
      unless rule.update(declared_params)
        session[:mail_tracking_rule_error] = { 'id' => rule.id.to_s, 'values' => declared_params.to_h }
      end
    end
    redirect_to edit_user_url(id: params[:user][:id])
  end

  private

  def mail_tracking_rule_params
    params.require(:mail_tracking_rule).permit(:mail_part, :includes, :tracker_name, :assigned_group_id, :assigned_project_id, :end_duration, :priority)
  end

  def ensure_group_membership(project_id, group_id, role_id)
    return if project_id.blank? || group_id.blank? || role_id.blank?

    project = Project.find_by(id: project_id)
    role = Role.find_by(id: role_id, assignable: true)
    return if project.nil? || role.nil?

    member = Member.find_by(project_id: project.id, user_id: group_id)
    if member
      member.roles << role unless member.roles.include?(role)
    else
      Member.create!(project_id: project.id, user_id: group_id, role_ids: [role.id])
    end
  end
end