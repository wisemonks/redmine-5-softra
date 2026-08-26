$( document ).ready(function() {
  $('.input-duration').durationPicker();
  $('#duration').durationPicker({
    lang: 'en',
    formatter: function (s) {
      return s;
    },
    showSeconds: false
  });

  $('#add_rule').on('click', function(){
    var template = document.getElementById('new_rule_template');
    var clone = document.importNode(template.content, true);
    var $clone = $(clone);
    $('.mail_tracker_rules').append($clone);
    $('.mail_tracker_rules fieldset:last .search-select').select2();
    $('.mail_tracker_rules fieldset:last .input-duration').durationPicker();
  });

  $(document).on('change', 'select.assigned_project_select', function(){
    var form = $(this).closest('form');
    var groupSelect = form.find('select.assigned_group_select');
    var projectId = $(this).val();

    groupSelect.prop('disabled', true);

    if (!projectId) {
      groupSelect.empty().append(new Option('', '', true, true));
      groupSelect.val(null).trigger('change');
      groupSelect.prop('disabled', false);
      return;
    }

    $.ajax({
      method: 'get',
      url: '/mail_tracking_rules/assignable_groups',
      data: { project_id: projectId },
      success: function(groups) {
        groupSelect.empty().append(new Option('', '', true, true));
        $.each(groups, function(i, group){
          groupSelect.append(new Option(group[0], group[1], false, false));
        });
        groupSelect.val(null).trigger('change');
        groupSelect.prop('disabled', false);
      }
    });
  });

  var pendingGroupTargetSelect = null;
  var pendingGroupTargetRoleField = null;

  $(document).on('click', '.add_group_btn', function(){
    var form = $(this).closest('form');
    pendingGroupTargetSelect = form.find('select.assigned_group_select');
    pendingGroupTargetRoleField = form.find('.pending_role_id_field');
    showModal('mail_tracker_group_modal', 400);
  });

  $(document).on('click', '#modal_add_group_btn', function(){
    var groupId = $('#modal_group_select').val();
    var groupName = $('#modal_group_select option:selected').text();
    var roleId = $('#modal_role_select').val();

    if (pendingGroupTargetSelect && groupId) {
      var existingOption = pendingGroupTargetSelect.find('option[value="' + groupId + '"]');
      if (existingOption.length === 0) {
        pendingGroupTargetSelect.append(new Option(groupName, groupId, true, true));
      } else {
        pendingGroupTargetSelect.val(groupId);
      }
      pendingGroupTargetSelect.trigger('change');
    }
    if (pendingGroupTargetRoleField) {
      pendingGroupTargetRoleField.val(roleId);
    }
    hideModal(this);
  });

  $(document).on('click', '.delete_rule', function(e){
    var id = $(this).attr('data-id');
    if(confirm("Do you really want to delete this rule?")){
      if(id && id.length > 0){
        $.ajax({
          method: 'DELETE',
          beforeSend: function(xhr) {xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))},
          url: "/mail_tracking_rules/" + id,
          data: {
            obj: "realThing"
          },
          success: function(resp) {
            location.reload();
          }
        })
      } else {
        $(this).closest('fieldset').remove();
      }
    }

  });
});