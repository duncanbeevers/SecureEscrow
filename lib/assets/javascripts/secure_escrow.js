(function($, undefined) {
  var framesCount = 0;

  function handleRemoteEscrowSubmission(form) {
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


      response = {
        responseText: innerText
      };

      if (payload_error) {
        response.errorJSON = { error: payload_error };
      } else {
        response.responseJSON = json;
      }
 
      if (json && json.success) {
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

  $(formSubmitSelector).live('submit.secure_escrow', function(event) {
    var form     = $(this),
        escrow   = form.data('escrow'),
        isEscrow = escrow !== undefined;

    if (isEscrow) {
      if ('iframe' === escrow) {
        handleRemoteEscrowSubmission(form);
      }
    }

  });

}(jQuery));
