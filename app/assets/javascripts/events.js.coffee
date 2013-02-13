# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/
jQuery ->
  $('#event_location_id').select2(width: 'element')
  $('#event_organizer_user_id').select2(width: 'element')

  dateChanged = ->
    date = $(this).val()
    date_components = date.split('/')
    month = date_components[0]
    day = date_components[1]
    year = date_components[2]
    index = parseInt(this.id.match(/\d+/)[0], 10)

    $('#event_event_sessions_attributes_' + index + '_starts_at_1i').val(year)
    $('#event_event_sessions_attributes_' + index + '_starts_at_2i').val(month)
    $('#event_event_sessions_attributes_' + index + '_starts_at_3i').val(day)
    $('#event_event_sessions_attributes_' + index + '_ends_at_1i').val(year)
    $('#event_event_sessions_attributes_' + index + '_ends_at_2i').val(month)
    $('#event_event_sessions_attributes_' + index + '_ends_at_3i').val(day)

  $('.datepicker').datepicker()
  $('.datepicker').on('change', dateChanged)

  $(document).on 'nested:fieldAdded', (event) ->
    $field = event.field
    $dateField = $field.find('.datepicker')
    $dateField.datepicker()
    $dateField.on('change', dateChanged)