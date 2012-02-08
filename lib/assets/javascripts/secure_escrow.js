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
          inner_text, http_status, wrapper_json, json, response;

      try {
        inner_text = $(iframe[0].contentWindow.document).find("#response").text();
        try {
          wrapper_json = JSON.parse(inner_text);
          http_status = wrapper_json.status;
          try {
            json = JSON.parse(wrapper_json.body);
          } catch(_3) {
            payload_error = 'Error parsing original body';
          }
        } catch(_2) {
          payload_error = 'Error parsing JSON response';
        }
      } catch(_1) {
        payload_error = 'Error accessing response body';
      }

      response = {
        responseText: wrapper_json.body
      };

      if (http_status >= 200 && http_status < 300) {
        form.trigger('ajax:success', [json]);
      } else {
        form.trigger('ajax:error', [response]);
      }
      form.trigger('ajax:complete', [response]);

      iframe.remove();
    }

    iframe.load(onLoad);
    form.attr('target', name);
  }

  var formSubmitSelector = 'form';

  $(function() {
    $(document.body).on('submit.secure_escrow', 'form',
      function(event) {
        var form     = $(this),
            escrow   = form.data('escrow'),
            isEscrow = escrow !== undefined;

        if (isEscrow && 'iframe' === escrow) {
          handleRemoteEscrowSubmission(form);
        }
      }
    );
  });

}(jQuery));
