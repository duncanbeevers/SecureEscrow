require "action_dispatch"
require "action_pack"

module SecureEscrow
  module Railtie
    module Routing
      def escrow *args, &block
        options = args.extract_options!
        defaults = options[:defaults] || {}
        defaults[:escrow] = true
        args.push options
        post *args, &block
      end
    end

    module ActionViewHelper
      DATA_ESCROW = 'data-escrow'
      IFRAME = 'iframe'
      POST   = 'POST'

      def escrow_form_for record, options = {}, &proc
        options[:html] ||= {}

        stringy_record = case record
        when String, Symbol then true
        else false
        end
        apply_form_for_options!(record, options) unless stringy_record


        form_for record, escrow_options(options, POST), &proc
      end

      def escrow_form_tag url_for_options = {}, options = {}, &block
        form_tag url_for_options, escrow_options(options, POST), &block
      end

      private
      def escrow_options options, method
        # Rewrite URL to point to secure domain
        app = Rails.application
        config = app.config.secure_escrow

        submission_url = controller.url_for(
          app.routes.recognize_path(options[:url], method: method).
            merge(
              host:     config[:secure_domain_name]     || request.host,
              protocol: config[:secure_domain_protocol] || request.protocol,
              port:     config[:secure_domain_port]     || request.port,
            ))

        options[:url] = submission_url

        # Add data-escrow attribute to the form element
        html_options = options[:html] || {}

        escrow_method = options.delete(:remote) ? IFRAME : POST
        options.merge(html: html_options.merge(DATA_ESCROW => escrow_method))
      end
    end
  end
end

