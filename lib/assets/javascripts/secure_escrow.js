(function($, undefined) {
  var framesCount = 0;

  function handleEscrowSubmission(form) {
    framesCount++;
    var name = 'escrow_frame_' + framesCount;

    // Create a hidden iframe to submit a form to
    var iframe = $('<iframe>', { name: name, id: name }).
      css({ display: 'none' }).
      appendTo('body');

    // onLoad handler attached to hidden iframe
    // Consumes iframe content and bubbles it up as an ajax response
    function onLoad() {
      var payload_error,
          innerText, json, response;

      try {
        innerText = iframe[0].contentWindow.document.body.innerText;
        try {
          json = JSON.parse(innerText);
        } catch(_2) {
          payload_error = 'Error parsing JSON response';
        }
      } catch(_1) {
        payload_error = 'Error accessing response body';
      }

      if (payload_error) {
        json = { error: payload_error };
      }

      response = {
        responseText: innerText,
        responseJSON: json
      };

      if (json.success) {
        form.trigger('ajax:success', response);
      } else {
        form.trigger('ajax:error', response);
      }
      form.trigger('ajax:complete', response);
    }

    iframe.load(onLoad);
    form.attr('target', name);
  }

  var formSubmitSelector = 'form';

  $(formSubmitSelector).live('submit.secure_escrow', function(element) {
    var form = $(this),
      isEscrow = form.data('escrow') !== undefined;

    var rails = $.rails;

    if (isEscrow) {
      handleEscrowSubmission(form);
    }

  });
  

}(jQuery));
